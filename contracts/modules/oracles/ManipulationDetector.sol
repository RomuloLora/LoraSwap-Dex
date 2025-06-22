// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IManipulationDetector.sol";
import "./interfaces/IOracleAggregator.sol";

/**
 * @title ManipulationDetector
 * @dev Detecção de manipulação de preços
 */
contract ManipulationDetector is IManipulationDetector, Ownable {
    mapping(address => ManipulationConfig) public manipulationConfigs;
    mapping(address => ManipulationData[]) public manipulationHistory;
    mapping(address => uint256[]) public priceHistory;
    mapping(address => uint256) public lastUpdateTime;
    
    uint256 public constant MAX_PRICE_CHANGE_PERCENT = 50; // 50%
    uint256 public constant MIN_UPDATE_INTERVAL = 60; // 1 minuto
    uint256 public constant MAX_HISTORY_SIZE = 50;
    
    uint256 public totalManipulationsDetected;
    uint256 public totalFalsePositives;
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Detecta manipulação de preço
     */
    function detectManipulation(
        address asset,
        address oracle,
        uint256 newPrice,
        bytes calldata priceData
    ) external view override returns (bool isManipulated, string memory reason) {
        ManipulationConfig storage config = manipulationConfigs[asset];
        
        if (!config.isEnabled) {
            return (false, "");
        }
        
        // Verificar intervalo mínimo entre atualizações
        if (block.timestamp < lastUpdateTime[asset] + config.minUpdateInterval) {
            return (true, "Update too frequent");
        }
        
        // Verificar mudança de preço excessiva
        if (priceHistory[asset].length > 0) {
            uint256 lastPrice = priceHistory[asset][priceHistory[asset].length - 1];
            uint256 priceChange;
            
            if (newPrice >= lastPrice) {
                priceChange = (newPrice - lastPrice) * 100 / lastPrice;
            } else {
                priceChange = (lastPrice - newPrice) * 100 / lastPrice;
            }
            
            if (priceChange > config.maxPriceChangePercent) {
                return (true, "Price spike detected");
            }
        }
        
        // Verificar padrões suspeitos
        if (priceHistory[asset].length >= 3) {
            // Verificar se há padrão de pump and dump
            uint256[] memory recentPrices = new uint256[](3);
            for (uint256 i = 0; i < 3; i++) {
                recentPrices[i] = priceHistory[asset][priceHistory[asset].length - 3 + i];
            }
            
            if (_detectPumpAndDump(recentPrices)) {
                return (true, "Pump and dump pattern");
            }
            
            // Verificar se há manipulação de volume
            if (_detectVolumeManipulation(priceData)) {
                return (true, "Volume manipulation");
            }
        }
        
        return (false, "");
    }
    
    /**
     * @dev Analisa padrão de preços
     */
    function analyzePricePattern(
        address asset,
        uint256[] calldata prices
    ) external view override returns (ManipulationData memory) {
        if (prices.length < 3) {
            return ManipulationData({
                isManipulated: false,
                reason: "Insufficient data",
                severity: 0,
                timestamp: block.timestamp,
                priceChange: 0,
                volumeChange: 0
            });
        }
        
        bool isManipulated = false;
        string memory reason = "";
        uint256 severity = 0;
        uint256 priceChange = 0;
        uint256 volumeChange = 0;
        
        // Calcular mudança de preço
        if (prices[prices.length - 1] > prices[0]) {
            priceChange = (prices[prices.length - 1] - prices[0]) * 100 / prices[0];
        } else {
            priceChange = (prices[0] - prices[prices.length - 1]) * 100 / prices[0];
        }
        
        // Verificar padrões suspeitos
        if (_detectPumpAndDump(prices)) {
            isManipulated = true;
            reason = "Pump and dump pattern";
            severity = 80;
        } else if (priceChange > 20) {
            isManipulated = true;
            reason = "Excessive price change";
            severity = 60;
        } else if (_detectWashTrading(prices)) {
            isManipulated = true;
            reason = "Wash trading pattern";
            severity = 90;
        }
        
        return ManipulationData({
            isManipulated: isManipulated,
            reason: reason,
            severity: severity,
            timestamp: block.timestamp,
            priceChange: priceChange,
            volumeChange: volumeChange
        });
    }
    
    /**
     * @dev Define configuração de detecção para um asset
     */
    function setManipulationConfig(
        address asset,
        ManipulationConfig calldata config
    ) external override onlyOwner {
        require(config.maxPriceChangePercent <= MAX_PRICE_CHANGE_PERCENT, "Change too high");
        require(config.minUpdateInterval >= MIN_UPDATE_INTERVAL, "Interval too short");
        
        manipulationConfigs[asset] = config;
        
        emit ManipulationConfigUpdated(asset, config);
    }
    
    /**
     * @dev Retorna configuração de detecção de um asset
     */
    function getManipulationConfig(address asset) external view override returns (ManipulationConfig memory) {
        return manipulationConfigs[asset];
    }
    
    /**
     * @dev Retorna histórico de manipulações de um asset
     */
    function getManipulationHistory(address asset) external view override returns (ManipulationData[] memory) {
        return manipulationHistory[asset];
    }
    
    /**
     * @dev Reporta falso positivo
     */
    function reportFalsePositive(address asset, string calldata reason) external override {
        totalFalsePositives++;
        emit FalsePositiveReported(asset, reason);
    }
    
    /**
     * @dev Registra novo preço para análise
     */
    function recordPrice(address asset, uint256 newPrice) external {
        priceHistory[asset].push(newPrice);
        lastUpdateTime[asset] = block.timestamp;
        
        // Manter histórico limitado
        if (priceHistory[asset].length > MAX_HISTORY_SIZE) {
            // Remover o item mais antigo
            for (uint256 i = 0; i < priceHistory[asset].length - 1; i++) {
                priceHistory[asset][i] = priceHistory[asset][i + 1];
            }
            priceHistory[asset].pop();
        }
        
        // Verificar manipulação
        if (priceHistory[asset].length >= 3) {
            uint256[] memory recentPrices = new uint256[](3);
            for (uint256 i = 0; i < 3; i++) {
                recentPrices[i] = priceHistory[asset][priceHistory[asset].length - 3 + i];
            }
            
            ManipulationData memory analysis = this.analyzePricePattern(asset, recentPrices);
            
            if (analysis.isManipulated) {
                manipulationHistory[asset].push(analysis);
                totalManipulationsDetected++;
                
                emit ManipulationDetected(asset, analysis.reason, analysis.severity);
            }
        }
    }
    
    /**
     * @dev Detecta padrão de pump and dump
     */
    function _detectPumpAndDump(uint256[] memory prices) internal pure returns (bool) {
        if (prices.length < 3) return false;
        
        // Verificar se há aumento seguido de queda rápida
        bool hasPump = prices[1] > prices[0] * 110 / 100; // 10% de aumento
        bool hasDump = prices[2] < prices[1] * 90 / 100; // 10% de queda
        
        return hasPump && hasDump;
    }
    
    /**
     * @dev Detecta wash trading
     */
    function _detectWashTrading(uint256[] memory prices) internal pure returns (bool) {
        if (prices.length < 5) return false;
        
        // Verificar se há padrão de preços muito estáveis (suspeito)
        uint256 totalVariation = 0;
        for (uint256 i = 1; i < prices.length; i++) {
            uint256 variation;
            if (prices[i] >= prices[i-1]) {
                variation = (prices[i] - prices[i-1]) * 100 / prices[i-1];
            } else {
                variation = (prices[i-1] - prices[i]) * 100 / prices[i-1];
            }
            totalVariation += variation;
        }
        
        // Se a variação total for muito baixa, pode ser wash trading
        return totalVariation < 5; // Menos de 5% de variação total
    }
    
    /**
     * @dev Detecta manipulação de volume (simulado)
     */
    function _detectVolumeManipulation(bytes memory priceData) internal pure returns (bool) {
        // Em uma implementação real, analisaria dados de volume
        // Por simplicidade, retorna false
        return false;
    }
    
    /**
     * @dev Retorna estatísticas de detecção
     */
    function getDetectionStats() external view returns (
        uint256 _totalManipulationsDetected,
        uint256 _totalFalsePositives
    ) {
        return (totalManipulationsDetected, totalFalsePositives);
    }
    
    /**
     * @dev Limpa histórico de manipulações de um asset
     */
    function clearManipulationHistory(address asset) external onlyOwner {
        delete manipulationHistory[asset];
    }
    
    /**
     * @dev Limpa histórico de preços de um asset
     */
    function clearPriceHistory(address asset) external onlyOwner {
        delete priceHistory[asset];
        delete lastUpdateTime[asset];
    }
} 