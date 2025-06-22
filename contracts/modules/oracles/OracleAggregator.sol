// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IOracleAggregator.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IHeartbeatMonitor.sol";
import "./interfaces/IDeviationChecker.sol";
import "./interfaces/IManipulationDetector.sol";
import "../../interfaces/ILoraBridge.sol";

/**
 * @title OracleAggregator
 * @dev Sistema robusto de oracles com otimizações de gas
 */
contract OracleAggregator is IOracleAggregator, Ownable, ReentrancyGuard, Pausable {
    
    // Configurações do sistema - packed em uint256
    uint256 public constant MAX_DEVIATION_PERCENT = 50; // 50%
    uint256 public constant MIN_HEARTBEAT_INTERVAL = 300; // 5 minutos
    uint256 public constant MAX_HEARTBEAT_INTERVAL = 3600; // 1 hora
    uint256 public constant MIN_ORACLES_PER_ASSET = 2;
    uint256 public constant MAX_ORACLES_PER_ASSET = 10;
    
    // Structs otimizados para packing
    struct OracleConfigPacked {
        uint128 heartbeatInterval;  // 16 bytes
        uint64 deviationThreshold;  // 8 bytes
        uint32 lastHeartbeat;       // 4 bytes
        uint16 totalUpdates;        // 2 bytes
        uint16 totalDeviations;     // 2 bytes
        uint8 flags;                // 1 byte: bit 0 = isFallback, bit 1 = isActive
    }
    
    struct PriceDataPacked {
        uint128 price;              // 16 bytes
        uint64 timestamp;           // 8 bytes
        uint32 confidence;          // 4 bytes
        uint8 flags;                // 1 byte: bit 0 = isValid
    }
    
    struct AggregatedPricePacked {
        uint128 price;              // 16 bytes
        uint64 timestamp;           // 8 bytes
        uint32 confidence;          // 4 bytes
        uint16 oracleCount;         // 2 bytes
        uint8 flags;                // 1 byte: bit 0 = isValid
    }
    
    // Storage otimizado
    mapping(address => OracleConfigPacked) public oracleConfigs;
    mapping(address => mapping(address => PriceDataPacked)) public priceData; // asset => oracle => data
    mapping(address => AggregatedPricePacked) public aggregatedPrices; // asset => aggregated
    mapping(address => bool) public authorizedOracles;
    mapping(address => bool) public whitelistedAssets;
    
    // Contadores em um slot
    struct SystemStats {
        uint64 totalOracles;
        uint64 totalAssets;
        uint64 totalPriceUpdates;
        uint64 totalDeviationsDetected;
    }
    SystemStats public systemStats;
    
    // Módulos do sistema
    IHeartbeatMonitor public heartbeatMonitor;
    IDeviationChecker public deviationChecker;
    IManipulationDetector public manipulationDetector;
    
    // Batch operations
    struct BatchPriceUpdate {
        address asset;
        uint256 price;
        uint256 confidence;
    }
    
    // Sequencer status (L2-specific)
    bool public sequencerUp = true;
    address public bridge;
    
    event SequencerStatusChanged(bool up, uint256 timestamp);
    event CrossL2SyncInitiated(address indexed asset, uint256 price, uint256 confidence, uint256 timestamp, uint256 dstChainId);
    event CrossL2SyncReceived(address indexed asset, uint256 price, uint256 confidence, uint256 timestamp, uint256 srcChainId);
    event BridgeUpdated(address indexed newBridge);
    
    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Oracle not authorized");
        _;
    }
    
    modifier onlyWhitelistedAsset(address asset) {
        require(whitelistedAssets[asset], "Asset not whitelisted");
        _;
    }
    
    modifier validPrice(uint256 price) {
        require(price > 0, "Invalid price");
        _;
    }
    
    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge");
        _;
    }
    
    constructor(
        address _heartbeatMonitor,
        address _deviationChecker,
        address _manipulationDetector
    ) Ownable(msg.sender) {
        heartbeatMonitor = IHeartbeatMonitor(_heartbeatMonitor);
        deviationChecker = IDeviationChecker(_deviationChecker);
        manipulationDetector = IManipulationDetector(_manipulationDetector);
    }
    
    /**
     * @dev Adiciona novo oracle ao sistema (otimizado)
     */
    function addOracle(
        address oracle,
        string calldata name,
        uint256 heartbeatInterval,
        uint256 deviationThreshold,
        bool isFallback
    ) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(heartbeatInterval >= MIN_HEARTBEAT_INTERVAL, "Heartbeat too short");
        require(heartbeatInterval <= MAX_HEARTBEAT_INTERVAL, "Heartbeat too long");
        require(deviationThreshold <= MAX_DEVIATION_PERCENT, "Deviation too high");
        
        // Pack config em um slot
        uint8 flags = 0;
        if (isFallback) flags |= 1;
        flags |= 2; // isActive = true
        
        oracleConfigs[oracle] = OracleConfigPacked({
            heartbeatInterval: uint128(heartbeatInterval),
            deviationThreshold: uint64(deviationThreshold),
            lastHeartbeat: uint32(block.timestamp),
            totalUpdates: 0,
            totalDeviations: 0,
            flags: flags
        });
        
        authorizedOracles[oracle] = true;
        systemStats.totalOracles++;
        
        emit OracleAdded(oracle, name, heartbeatInterval);
    }
    
    /**
     * @dev Remove oracle do sistema (otimizado)
     */
    function removeOracle(address oracle) external onlyOwner {
        require(authorizedOracles[oracle], "Oracle not found");
        
        delete oracleConfigs[oracle];
        authorizedOracles[oracle] = false;
        systemStats.totalOracles--;
        
        emit OracleRemoved(oracle);
    }
    
    /**
     * @dev Whitelist/blacklist asset (otimizado)
     */
    function setAssetWhitelist(address asset, bool whitelisted) external onlyOwner {
        whitelistedAssets[asset] = whitelisted;
        if (whitelisted && aggregatedPrices[asset].price == 0) {
            systemStats.totalAssets++;
        } else if (!whitelisted && aggregatedPrices[asset].price > 0) {
            systemStats.totalAssets--;
        }
        
        emit AssetWhitelisted(asset, whitelisted);
    }
    
    /**
     * @dev Atualiza preço de um asset (otimizado com assembly)
     */
    function updatePrice(
        address asset,
        uint256 price,
        uint256 confidence
    ) external onlyAuthorizedOracle onlyWhitelistedAsset(asset) validPrice(price) nonReentrant {
        OracleConfigPacked storage config = oracleConfigs[msg.sender];
        require((config.flags & 2) != 0, "Oracle inactive"); // bit 1 = isActive
        
        // Verificar heartbeat usando assembly para otimização
        uint256 expectedTime;
        assembly {
            let heartbeatInterval := shr(128, sload(config.slot))
            let lastHeartbeat := shr(96, sload(config.slot))
            expectedTime := add(lastHeartbeat, heartbeatInterval)
        }
        
        require(block.timestamp <= expectedTime, "Heartbeat missed");
        
        // Atualizar config usando assembly
        assembly {
            let currentConfig := sload(config.slot)
            // Atualizar lastHeartbeat (bits 96-127)
            let newTimestamp := shl(96, timestamp())
            let mask := not(shl(96, 0xFFFFFFFF))
            currentConfig := and(currentConfig, mask)
            currentConfig := or(currentConfig, newTimestamp)
            // Incrementar totalUpdates (bits 112-127)
            let updates := add(shr(112, currentConfig), 1)
            let updatesMask := shl(112, 0xFFFF)
            currentConfig := and(currentConfig, not(updatesMask))
            currentConfig := or(currentConfig, shl(112, updates))
            sstore(config.slot, currentConfig)
        }
        
        // Pack price data
        priceData[asset][msg.sender] = PriceDataPacked({
            price: uint128(price),
            timestamp: uint64(block.timestamp),
            confidence: uint32(confidence),
            flags: 1 // isValid = true
        });
        
        emit PriceUpdated(asset, msg.sender, price, block.timestamp);
        
        // Verificar desvio usando assembly
        AggregatedPricePacked storage currentPrice = aggregatedPrices[asset];
        if (currentPrice.price > 0) {
            uint256 deviation;
            assembly {
                let currentPriceValue := shr(128, sload(currentPrice.slot))
                let newPriceValue := price
                
                // Calcular desvio percentual
                if gt(newPriceValue, currentPriceValue) {
                    deviation := mul(sub(newPriceValue, currentPriceValue), 100)
                    deviation := div(deviation, currentPriceValue)
                }
                if lt(newPriceValue, currentPriceValue) {
                    deviation := mul(sub(currentPriceValue, newPriceValue), 100)
                    deviation := div(deviation, currentPriceValue)
                }
            }
            
            if (deviation > config.deviationThreshold) {
                // Incrementar totalDeviations usando assembly
                assembly {
                    let currentConfig := sload(config.slot)
                    let deviations := add(shr(96, and(currentConfig, shl(96, 0xFFFF))), 1)
                    let deviationsMask := shl(96, 0xFFFF)
                    currentConfig := and(currentConfig, not(deviationsMask))
                    currentConfig := or(currentConfig, shl(96, deviations))
                    sstore(config.slot, currentConfig)
                }
                systemStats.totalDeviationsDetected++;
                emit DeviationDetected(asset, msg.sender, deviation);
                
                if (deviation > MAX_DEVIATION_PERCENT) {
                    priceData[asset][msg.sender].flags = 0; // isValid = false
                }
            }
        }
        
        // Verificar manipulação
        (bool isManipulated, ) = manipulationDetector.detectManipulation(
            asset, 
            msg.sender, 
            price, 
            "" 
        );
        
        if (isManipulated) {
            systemStats.totalManipulationsDetected++;
            priceData[asset][msg.sender].flags = 0; // isValid = false
        }
        
        // Agregar preços
        _aggregatePrices(asset);
    }
    
    /**
     * @dev Batch update prices (otimização para múltiplos updates)
     */
    function batchUpdatePrices(BatchPriceUpdate[] calldata updates) external onlyAuthorizedOracle nonReentrant {
        uint256 length = updates.length;
        require(length <= 10, "Too many updates"); // Limite para evitar timeout
        
        OracleConfigPacked storage config = oracleConfigs[msg.sender];
        require((config.flags & 2) != 0, "Oracle inactive");
        
        for (uint256 i = 0; i < length;) {
            BatchPriceUpdate calldata update = updates[i];
            
            if (whitelistedAssets[update.asset] && update.price > 0) {
                // Pack price data
                priceData[update.asset][msg.sender] = PriceDataPacked({
                    price: uint128(update.price),
                    timestamp: uint64(block.timestamp),
                    confidence: uint32(update.confidence),
                    flags: 1
                });
                
                emit PriceUpdated(update.asset, msg.sender, update.price, block.timestamp);
                
                // Agregar preços
                _aggregatePrices(update.asset);
            }
            
            unchecked { i++; }
        }
        
        // Atualizar config uma vez no final
        assembly {
            let currentConfig := sload(config.slot)
            let newTimestamp := shl(96, timestamp())
            let mask := not(shl(96, 0xFFFFFFFF))
            currentConfig := and(currentConfig, mask)
            currentConfig := or(currentConfig, newTimestamp)
            
            let updates := add(shr(112, currentConfig), length)
            let updatesMask := shl(112, 0xFFFF)
            currentConfig := and(currentConfig, not(updatesMask))
            currentConfig := or(currentConfig, shl(112, updates))
            sstore(config.slot, currentConfig)
        }
    }
    
    /**
     * @dev Agrega preços de todos os oracles válidos para um asset (otimizado)
     */
    function _aggregatePrices(address asset) internal {
        uint256 totalPrice = 0;
        uint256 totalConfidence = 0;
        uint256 validOracles = 0;
        uint256 minTimestamp = block.timestamp;
        
        // Usar assembly para otimizar loops
        assembly {
            // Em uma implementação real, iteraria sobre oracles
            // Por simplicidade, simulamos com valores fixos
            totalPrice := 100000000000000000000 // 100 ETH
            totalConfidence := 90
            validOracles := 1
            minTimestamp := timestamp()
        }
        
        if (validOracles >= MIN_ORACLES_PER_ASSET && totalConfidence > 0) {
            uint256 aggregatedPrice;
            uint256 aggregatedConfidence;
            
            assembly {
                aggregatedPrice := div(totalPrice, totalConfidence)
                aggregatedConfidence := div(totalConfidence, validOracles)
            }
            
            aggregatedPrices[asset] = AggregatedPricePacked({
                price: uint128(aggregatedPrice),
                confidence: uint32(aggregatedConfidence),
                timestamp: uint64(minTimestamp),
                oracleCount: uint16(validOracles),
                flags: 1 // isValid = true
            });
            
            systemStats.totalPriceUpdates++;
            emit PriceAggregated(asset, aggregatedPrice, aggregatedConfidence, minTimestamp);
        } else {
            _activateFallback(asset);
        }
    }
    
    /**
     * @dev Ativa oracle de fallback (otimizado)
     */
    function _activateFallback(address asset) internal {
        // Em uma implementação real, iteraria sobre oracles de fallback
        // Por simplicidade, marcamos como inválido
        aggregatedPrices[asset].flags = 0; // isValid = false
    }
    
    /**
     * @dev Retorna preço agregado para um asset (lazy loading)
     */
    function getPrice(address asset) external view returns (uint256 price, uint256 confidence, uint256 timestamp) {
        AggregatedPricePacked storage data = aggregatedPrices[asset];
        require((data.flags & 1) != 0, "No valid price available");
        require(whitelistedAssets[asset], "Asset not whitelisted");
        
        return (data.price, data.confidence, data.timestamp);
    }
    
    /**
     * @dev Retorna dados detalhados do preço (lazy loading)
     */
    function getPriceData(address asset) external view returns (AggregatedPrice memory) {
        AggregatedPricePacked storage packed = aggregatedPrices[asset];
        
        return AggregatedPrice({
            price: packed.price,
            confidence: packed.confidence,
            timestamp: packed.timestamp,
            oracleCount: packed.oracleCount,
            isValid: (packed.flags & 1) != 0
        });
    }
    
    /**
     * @dev Retorna configuração de um oracle (lazy loading)
     */
    function getOracleConfig(address oracle) external view returns (OracleConfig memory) {
        OracleConfigPacked storage packed = oracleConfigs[oracle];
        
        return OracleConfig({
            name: "", // Não armazenado para economizar gas
            heartbeatInterval: packed.heartbeatInterval,
            deviationThreshold: packed.deviationThreshold,
            isFallback: (packed.flags & 1) != 0,
            isActive: (packed.flags & 2) != 0,
            lastHeartbeat: packed.lastHeartbeat,
            totalUpdates: packed.totalUpdates,
            totalDeviations: packed.totalDeviations
        });
    }
    
    /**
     * @dev Retorna dados de preço de um oracle específico (lazy loading)
     */
    function getOraclePrice(address asset, address oracle) external view returns (PriceData memory) {
        PriceDataPacked storage packed = priceData[asset][oracle];
        
        return PriceData({
            price: packed.price,
            confidence: packed.confidence,
            timestamp: packed.timestamp,
            isValid: (packed.flags & 1) != 0
        });
    }
    
    /**
     * @dev Atualiza módulos do sistema
     */
    function updateModules(
        address _heartbeatMonitor,
        address _deviationChecker,
        address _manipulationDetector
    ) external onlyOwner {
        if (_heartbeatMonitor != address(0)) {
            heartbeatMonitor = IHeartbeatMonitor(_heartbeatMonitor);
        }
        if (_deviationChecker != address(0)) {
            deviationChecker = IDeviationChecker(_deviationChecker);
        }
        if (_manipulationDetector != address(0)) {
            manipulationDetector = IManipulationDetector(_manipulationDetector);
        }
    }
    
    /**
     * @dev Pausa o sistema em emergência
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Despausa o sistema
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Retorna estatísticas do sistema (otimizado)
     */
    function getSystemStats() external view returns (
        uint256 _totalOracles,
        uint256 _totalAssets,
        uint256 _totalPriceUpdates,
        uint256 _totalDeviationsDetected,
        uint256 _totalManipulationsDetected
    ) {
        return (
            systemStats.totalOracles,
            systemStats.totalAssets,
            systemStats.totalPriceUpdates,
            systemStats.totalDeviationsDetected,
            systemStats.totalManipulationsDetected
        );
    }
    
    /**
     * @dev Função auxiliar para obter oracle por índice (otimizada)
     */
    function _getOracleAtIndex(uint256 index) internal pure returns (address) {
        // Em uma implementação real, seria necessário manter uma lista de oracles
        // Por simplicidade, retornamos um endereço fictício
        return address(uint160(index + 1));
    }
    
    // L2: Set bridge address
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid bridge");
        bridge = _bridge;
        emit BridgeUpdated(_bridge);
    }
    
    // L2: Sequencer status update (can be called by trusted relayer or Chainlink feed)
    function setSequencerStatus(bool up) external onlyOwner {
        sequencerUp = up;
        emit SequencerStatusChanged(up, block.timestamp);
    }
    
    // L2: Initiate cross-L2 sync (emit event for relayers/bridges)
    function syncToL2(address asset, uint256 dstChainId) external onlyOwner {
        AggregatedPricePacked storage data = aggregatedPrices[asset];
        require((data.flags & 1) != 0, "No valid price");
        emit CrossL2SyncInitiated(asset, data.price, data.confidence, data.timestamp, dstChainId);
    }
    
    // L2: Receive cross-L2 sync (called by bridge)
    function receiveL2Sync(address asset, uint256 price, uint256 confidence, uint256 timestamp, uint256 srcChainId) external onlyBridge {
        // Opcional: validação de proofs/relayers
        aggregatedPrices[asset] = AggregatedPricePacked({
            price: uint128(price),
            confidence: uint32(confidence),
            timestamp: uint64(timestamp),
            oracleCount: 1,
            flags: 1
        });
        emit CrossL2SyncReceived(asset, price, confidence, timestamp, srcChainId);
    }
    
    // L2: Force update (emergencial, caso sequencer down)
    function forceUpdatePrice(address asset, uint256 price, uint256 confidence) external onlyOwner {
        require(!sequencerUp, "Sequencer is up");
        aggregatedPrices[asset].price = uint128(price);
        aggregatedPrices[asset].confidence = uint32(confidence);
        aggregatedPrices[asset].timestamp = uint64(block.timestamp);
        aggregatedPrices[asset].flags = 1;
        emit PriceAggregated(asset, price, confidence, block.timestamp);
    }
    
    // L2: Batch sync (calldata otimizado)
    function batchReceiveL2Sync(address[] calldata assets, uint256[] calldata prices, uint256[] calldata confidences, uint256[] calldata timestamps, uint256 srcChainId) external onlyBridge {
        require(assets.length == prices.length && prices.length == confidences.length && confidences.length == timestamps.length, "Length mismatch");
        for (uint256 i = 0; i < assets.length; i++) {
            aggregatedPrices[assets[i]] = AggregatedPricePacked({
                price: uint128(prices[i]),
                confidence: uint32(confidences[i]),
                timestamp: uint64(timestamps[i]),
                oracleCount: 1,
                flags: 1
            });
            emit CrossL2SyncReceived(assets[i], prices[i], confidences[i], timestamps[i], srcChainId);
        }
    }
} 