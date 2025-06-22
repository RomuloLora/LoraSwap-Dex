// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IOracleAggregator.sol";

/**
 * @title CrossChainOracle
 * @dev Sistema de oracles cross-chain para sincronização entre blockchains
 */
contract CrossChainOracle is Ownable, ReentrancyGuard, Pausable {
    struct ChainConfig {
        uint256 chainId;
        string name;
        bool isActive;
        uint256 lastSync;
        uint256 syncInterval;
        uint256 priceTolerance;
    }
    
    struct CrossChainPrice {
        uint256 chainId;
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        bool isValid;
        bytes32 proof;
    }
    
    struct SyncRequest {
        address asset;
        uint256 targetChainId;
        uint256 requestId;
        uint256 timestamp;
        bool isCompleted;
        bytes32 proof;
    }
    
    // Configurações
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(address => mapping(uint256 => CrossChainPrice)) public crossChainPrices; // asset => chainId => price
    mapping(uint256 => SyncRequest) public syncRequests; // requestId => request
    mapping(address => bool) public authorizedRelayers;
    mapping(bytes32 => bool) public processedProofs;
    
    // Contadores
    uint256 public totalChains;
    uint256 public totalSyncRequests;
    uint256 public totalCrossChainUpdates;
    uint256 public nextRequestId;
    
    // Eventos
    event ChainRegistered(uint256 indexed chainId, string name, uint256 syncInterval);
    event ChainDeactivated(uint256 indexed chainId);
    event CrossChainPriceUpdated(address indexed asset, uint256 indexed chainId, uint256 price, uint256 timestamp);
    event SyncRequestCreated(uint256 indexed requestId, address indexed asset, uint256 targetChainId);
    event SyncRequestCompleted(uint256 indexed requestId, bytes32 proof);
    event RelayerAuthorized(address indexed relayer, bool authorized);
    event ProofProcessed(bytes32 indexed proof, uint256 indexed chainId);
    
    constructor() Ownable(msg.sender) {}
    
    modifier onlyAuthorizedRelayer() {
        require(authorizedRelayers[msg.sender], "Not authorized relayer");
        _;
    }
    
    modifier validChain(uint256 chainId) {
        require(chainConfigs[chainId].isActive, "Chain not active");
        _;
    }
    
    /**
     * @dev Registra uma nova blockchain
     */
    function registerChain(
        uint256 chainId,
        string calldata name,
        uint256 syncInterval,
        uint256 priceTolerance
    ) external onlyOwner {
        require(chainId != 0, "Invalid chain ID");
        require(syncInterval > 0, "Invalid sync interval");
        require(priceTolerance <= 50, "Tolerance too high");
        require(!chainConfigs[chainId].isActive, "Chain already registered");
        
        chainConfigs[chainId] = ChainConfig({
            chainId: chainId,
            name: name,
            isActive: true,
            lastSync: block.timestamp,
            syncInterval: syncInterval,
            priceTolerance: priceTolerance
        });
        
        totalChains++;
        emit ChainRegistered(chainId, name, syncInterval);
    }
    
    /**
     * @dev Desativa uma blockchain
     */
    function deactivateChain(uint256 chainId) external onlyOwner {
        require(chainConfigs[chainId].isActive, "Chain not active");
        
        chainConfigs[chainId].isActive = false;
        totalChains--;
        
        emit ChainDeactivated(chainId);
    }
    
    /**
     * @dev Autoriza/desautoriza relayers
     */
    function setRelayerAuthorization(address relayer, bool authorized) external onlyOwner {
        authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorized(relayer, authorized);
    }
    
    /**
     * @dev Cria requisição de sincronização
     */
    function createSyncRequest(
        address asset,
        uint256 targetChainId
    ) external validChain(targetChainId) returns (uint256 requestId) {
        require(asset != address(0), "Invalid asset");
        
        requestId = nextRequestId++;
        
        syncRequests[requestId] = SyncRequest({
            asset: asset,
            targetChainId: targetChainId,
            requestId: requestId,
            timestamp: block.timestamp,
            isCompleted: false,
            proof: bytes32(0)
        });
        
        totalSyncRequests++;
        emit SyncRequestCreated(requestId, asset, targetChainId);
        
        return requestId;
    }
    
    /**
     * @dev Atualiza preço cross-chain (chamado por relayers)
     */
    function updateCrossChainPrice(
        address asset,
        uint256 chainId,
        uint256 price,
        uint256 confidence,
        bytes32 proof
    ) external onlyAuthorizedRelayer validChain(chainId) nonReentrant {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        require(confidence <= 100, "Invalid confidence");
        require(!processedProofs[proof], "Proof already processed");
        
        // Verificar se o preço está dentro da tolerância
        CrossChainPrice storage existingPrice = crossChainPrices[asset][chainId];
        if (existingPrice.isValid && existingPrice.price > 0) {
            uint256 deviation;
            if (price >= existingPrice.price) {
                deviation = (price - existingPrice.price) * 100 / existingPrice.price;
            } else {
                deviation = (existingPrice.price - price) * 100 / existingPrice.price;
            }
            
            require(deviation <= chainConfigs[chainId].priceTolerance, "Price deviation too high");
        }
        
        // Atualizar preço
        crossChainPrices[asset][chainId] = CrossChainPrice({
            chainId: chainId,
            price: price,
            confidence: confidence,
            timestamp: block.timestamp,
            isValid: true,
            proof: proof
        });
        
        // Marcar proof como processado
        processedProofs[proof] = true;
        
        // Atualizar último sync da chain
        chainConfigs[chainId].lastSync = block.timestamp;
        
        totalCrossChainUpdates++;
        emit CrossChainPriceUpdated(asset, chainId, price, block.timestamp);
        emit ProofProcessed(proof, chainId);
    }
    
    /**
     * @dev Completa requisição de sincronização
     */
    function completeSyncRequest(
        uint256 requestId,
        bytes32 proof
    ) external onlyAuthorizedRelayer {
        SyncRequest storage request = syncRequests[requestId];
        require(request.asset != address(0), "Request not found");
        require(!request.isCompleted, "Request already completed");
        
        request.isCompleted = true;
        request.proof = proof;
        
        emit SyncRequestCompleted(requestId, proof);
    }
    
    /**
     * @dev Retorna preço cross-chain para um asset
     */
    function getCrossChainPrice(
        address asset,
        uint256 chainId
    ) external view returns (uint256 price, uint256 confidence, uint256 timestamp) {
        CrossChainPrice storage data = crossChainPrices[asset][chainId];
        require(data.isValid, "No valid price available");
        
        return (data.price, data.confidence, data.timestamp);
    }
    
    /**
     * @dev Retorna dados completos do preço cross-chain
     */
    function getCrossChainPriceData(
        address asset,
        uint256 chainId
    ) external view returns (CrossChainPrice memory) {
        return crossChainPrices[asset][chainId];
    }
    
    /**
     * @dev Retorna configuração de uma blockchain
     */
    function getChainConfig(uint256 chainId) external view returns (ChainConfig memory) {
        return chainConfigs[chainId];
    }
    
    /**
     * @dev Retorna requisição de sincronização
     */
    function getSyncRequest(uint256 requestId) external view returns (SyncRequest memory) {
        return syncRequests[requestId];
    }
    
    /**
     * @dev Verifica se uma blockchain precisa de sincronização
     */
    function needsSync(uint256 chainId) external view returns (bool) {
        ChainConfig storage config = chainConfigs[chainId];
        if (!config.isActive) return false;
        
        return block.timestamp > config.lastSync + config.syncInterval;
    }
    
    /**
     * @dev Retorna estatísticas do sistema cross-chain
     */
    function getCrossChainStats() external view returns (
        uint256 _totalChains,
        uint256 _totalSyncRequests,
        uint256 _totalCrossChainUpdates
    ) {
        return (totalChains, totalSyncRequests, totalCrossChainUpdates);
    }
    
    /**
     * @dev Retorna lista de blockchains ativas
     */
    function getActiveChains() external view returns (uint256[] memory) {
        uint256[] memory activeChains = new uint256[](totalChains);
        uint256 count = 0;
        
        // Em uma implementação real, seria necessário iterar sobre todas as chains
        // Por simplicidade, retornamos uma lista vazia
        return activeChains;
    }
    
    /**
     * @dev Verifica se um proof foi processado
     */
    function isProofProcessed(bytes32 proof) external view returns (bool) {
        return processedProofs[proof];
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
     * @dev Atualiza configuração de uma blockchain
     */
    function updateChainConfig(
        uint256 chainId,
        uint256 syncInterval,
        uint256 priceTolerance
    ) external onlyOwner validChain(chainId) {
        require(syncInterval > 0, "Invalid sync interval");
        require(priceTolerance <= 50, "Tolerance too high");
        
        ChainConfig storage config = chainConfigs[chainId];
        config.syncInterval = syncInterval;
        config.priceTolerance = priceTolerance;
    }
} 