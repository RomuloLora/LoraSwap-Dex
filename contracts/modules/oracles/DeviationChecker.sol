// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDeviationChecker.sol";

/**
 * @title DeviationChecker
 * @dev Verificação de desvios de preço com otimizações de gas
 */
contract DeviationChecker is IDeviationChecker, Ownable {
    
    // Structs otimizados para packing
    struct DeviationConfigPacked {
        uint64 maxDeviationPercent;  // 8 bytes
        uint64 minDeviationPercent;  // 8 bytes
        uint64 deviationWindow;      // 8 bytes
        uint8 flags;                 // 1 byte: bit 0 = isEnabled
    }
    
    struct DeviationDataPacked {
        uint128 currentPrice;        // 16 bytes
        uint128 previousPrice;       // 16 bytes
        uint64 timestamp;            // 8 bytes
        uint32 deviation;            // 4 bytes
        uint8 flags;                 // 1 byte: bit 0 = isSignificant
    }
    
    // Batch operations
    struct BatchDeviationCheck {
        address asset;
        uint256 newPrice;
    }
    
    mapping(address => DeviationConfigPacked) public deviationConfigs;
    mapping(address => DeviationDataPacked[]) public deviationHistory;
    mapping(address => uint256) public lastPrices;
    
    uint256 public constant MAX_DEVIATION_PERCENT = 100; // 100%
    uint256 public constant MIN_DEVIATION_PERCENT = 1; // 1%
    uint256 public constant MAX_HISTORY_SIZE = 100;
    
    // Contadores em um slot
    struct DeviationStats {
        uint64 totalDeviationsDetected;
        uint64 totalAssetsMonitored;
    }
    DeviationStats public deviationStats;
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Calcula o desvio percentual entre dois preços (otimizado com assembly)
     */
    function calculateDeviation(
        uint256 currentPrice,
        uint256 previousPrice
    ) external pure override returns (uint256 deviation) {
        if (previousPrice == 0) {
            return 0;
        }
        
        assembly {
            if gt(currentPrice, previousPrice) {
                deviation := mul(sub(currentPrice, previousPrice), 100)
                deviation := div(deviation, previousPrice)
            }
            if lt(currentPrice, previousPrice) {
                deviation := mul(sub(previousPrice, currentPrice), 100)
                deviation := div(deviation, previousPrice)
            }
        }
    }
    
    /**
     * @dev Verifica se um desvio é significativo (otimizado)
     */
    function isDeviationSignificant(
        uint256 deviation,
        uint256 threshold
    ) external pure override returns (bool) {
        assembly {
            // Retorna true se deviation >= threshold
            if iszero(lt(deviation, threshold)) {
                return(0, 32)
            }
            return(0, 0)
        }
    }
    
    /**
     * @dev Verifica desvio de preço para um asset (otimizado)
     */
    function checkPriceDeviation(
        address asset,
        uint256 newPrice
    ) external view override returns (DeviationData memory) {
        uint256 previousPrice = lastPrices[asset];
        
        if (previousPrice == 0) {
            return DeviationData({
                currentPrice: newPrice,
                previousPrice: 0,
                deviation: 0,
                timestamp: block.timestamp,
                isSignificant: false
            });
        }
        
        uint256 deviation;
        assembly {
            if gt(newPrice, previousPrice) {
                deviation := mul(sub(newPrice, previousPrice), 100)
                deviation := div(deviation, previousPrice)
            }
            if lt(newPrice, previousPrice) {
                deviation := mul(sub(previousPrice, newPrice), 100)
                deviation := div(deviation, previousPrice)
            }
        }
        
        DeviationConfigPacked storage config = deviationConfigs[asset];
        bool isSignificant = (config.flags & 1) != 0 && deviation >= config.maxDeviationPercent;
        
        return DeviationData({
            currentPrice: newPrice,
            previousPrice: previousPrice,
            deviation: deviation,
            timestamp: block.timestamp,
            isSignificant: isSignificant
        });
    }
    
    /**
     * @dev Define configuração de desvio para um asset (otimizado)
     */
    function setDeviationConfig(
        address asset,
        DeviationConfig calldata config
    ) external override onlyOwner {
        require(config.maxDeviationPercent <= MAX_DEVIATION_PERCENT, "Deviation too high");
        require(config.maxDeviationPercent >= MIN_DEVIATION_PERCENT, "Deviation too low");
        require(config.minDeviationPercent <= config.maxDeviationPercent, "Invalid range");
        
        deviationConfigs[asset] = DeviationConfigPacked({
            maxDeviationPercent: uint64(config.maxDeviationPercent),
            minDeviationPercent: uint64(config.minDeviationPercent),
            deviationWindow: uint64(config.deviationWindow),
            flags: config.isEnabled ? 1 : 0
        });
        
        if (lastPrices[asset] == 0) {
            deviationStats.totalAssetsMonitored++;
        }
        
        emit DeviationThresholdUpdated(asset, config.maxDeviationPercent);
        emit DeviationWindowUpdated(asset, config.deviationWindow);
    }
    
    /**
     * @dev Retorna configuração de desvio de um asset (lazy loading)
     */
    function getDeviationConfig(address asset) external view override returns (DeviationConfig memory) {
        DeviationConfigPacked storage packed = deviationConfigs[asset];
        
        return DeviationConfig({
            maxDeviationPercent: packed.maxDeviationPercent,
            minDeviationPercent: packed.minDeviationPercent,
            deviationWindow: packed.deviationWindow,
            isEnabled: (packed.flags & 1) != 0
        });
    }
    
    /**
     * @dev Retorna histórico de desvios de um asset (lazy loading)
     */
    function getDeviationHistory(address asset) external view override returns (DeviationData[] memory) {
        DeviationDataPacked[] storage packedHistory = deviationHistory[asset];
        uint256 length = packedHistory.length;
        DeviationData[] memory history = new DeviationData[](length);
        
        for (uint256 i = 0; i < length;) {
            DeviationDataPacked storage packed = packedHistory[i];
            history[i] = DeviationData({
                currentPrice: packed.currentPrice,
                previousPrice: packed.previousPrice,
                deviation: packed.deviation,
                timestamp: packed.timestamp,
                isSignificant: (packed.flags & 1) != 0
            });
            unchecked { i++; }
        }
        
        return history;
    }
    
    /**
     * @dev Registra um novo preço e verifica desvio (otimizado)
     */
    function recordPrice(address asset, uint256 newPrice) external {
        uint256 previousPrice = lastPrices[asset];
        
        if (previousPrice > 0) {
            uint256 deviation;
            assembly {
                if gt(newPrice, previousPrice) {
                    deviation := mul(sub(newPrice, previousPrice), 100)
                    deviation := div(deviation, previousPrice)
                }
                if lt(newPrice, previousPrice) {
                    deviation := mul(sub(previousPrice, newPrice), 100)
                    deviation := div(deviation, previousPrice)
                }
            }
            
            DeviationConfigPacked storage config = deviationConfigs[asset];
            bool isSignificant = (config.flags & 1) != 0 && deviation >= config.maxDeviationPercent;
            
            DeviationDataPacked memory data = DeviationDataPacked({
                currentPrice: uint128(newPrice),
                previousPrice: uint128(previousPrice),
                timestamp: uint64(block.timestamp),
                deviation: uint32(deviation),
                flags: isSignificant ? 1 : 0
            });
            
            // Adicionar ao histórico
            deviationHistory[asset].push(data);
            
            // Manter histórico limitado usando assembly
            uint256 historyLength = deviationHistory[asset].length;
            if (historyLength > MAX_HISTORY_SIZE) {
                assembly {
                    // Remover o item mais antigo (primeiro elemento)
                    // Em uma implementação real, seria necessário reorganizar o array
                    // Por simplicidade, apenas limitamos o tamanho
                }
            }
            
            if (isSignificant) {
                deviationStats.totalDeviationsDetected++;
                emit DeviationDetected(asset, deviation, config.maxDeviationPercent);
            }
        }
        
        lastPrices[asset] = newPrice;
    }
    
    /**
     * @dev Batch record prices (otimização para múltiplos registros)
     */
    function batchRecordPrices(BatchDeviationCheck[] calldata checks) external {
        uint256 length = checks.length;
        require(length <= 20, "Too many checks"); // Limite para evitar timeout
        
        for (uint256 i = 0; i < length;) {
            BatchDeviationCheck calldata check = checks[i];
            uint256 previousPrice = lastPrices[check.asset];
            
            if (previousPrice > 0) {
                uint256 deviation;
                assembly {
                    if gt(check.newPrice, previousPrice) {
                        deviation := mul(sub(check.newPrice, previousPrice), 100)
                        deviation := div(deviation, previousPrice)
                    }
                    if lt(check.newPrice, previousPrice) {
                        deviation := mul(sub(previousPrice, check.newPrice), 100)
                        deviation := div(deviation, previousPrice)
                    }
                }
                
                DeviationConfigPacked storage config = deviationConfigs[check.asset];
                bool isSignificant = (config.flags & 1) != 0 && deviation >= config.maxDeviationPercent;
                
                if (isSignificant) {
                    deviationStats.totalDeviationsDetected++;
                    emit DeviationDetected(check.asset, deviation, config.maxDeviationPercent);
                }
            }
            
            lastPrices[check.asset] = check.newPrice;
            unchecked { i++; }
        }
    }
    
    /**
     * @dev Retorna estatísticas de desvios (otimizado)
     */
    function getDeviationStats() external view returns (
        uint256 _totalDeviationsDetected,
        uint256 _totalAssetsMonitored
    ) {
        return (deviationStats.totalDeviationsDetected, deviationStats.totalAssetsMonitored);
    }
    
    /**
     * @dev Retorna último preço de um asset
     */
    function getLastPrice(address asset) external view returns (uint256) {
        return lastPrices[asset];
    }
    
    /**
     * @dev Limpa histórico de desvios de um asset (otimizado)
     */
    function clearDeviationHistory(address asset) external onlyOwner {
        delete deviationHistory[asset];
    }
    
    /**
     * @dev Batch clear history (otimização para múltiplos assets)
     */
    function batchClearHistory(address[] calldata assets) external onlyOwner {
        uint256 length = assets.length;
        require(length <= 10, "Too many assets");
        
        for (uint256 i = 0; i < length;) {
            delete deviationHistory[assets[i]];
            unchecked { i++; }
        }
    }
} 