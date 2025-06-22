// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IManipulationDetector
 * @dev Interface para detecção de manipulação de preços
 */
interface IManipulationDetector {
    
    struct ManipulationConfig {
        uint256 maxPriceChangePercent;
        uint256 minUpdateInterval;
        uint256 suspiciousVolumeThreshold;
        uint256 priceSpikeThreshold;
        bool isEnabled;
    }
    
    struct ManipulationData {
        bool isManipulated;
        string reason;
        uint256 severity;
        uint256 timestamp;
        uint256 priceChange;
        uint256 volumeChange;
    }
    
    // Eventos
    event ManipulationDetected(address indexed asset, string reason, uint256 severity);
    event ManipulationConfigUpdated(address indexed asset, ManipulationConfig config);
    event FalsePositiveReported(address indexed asset, string reason);
    
    // Funções principais
    function detectManipulation(
        address asset,
        address oracle,
        uint256 newPrice,
        bytes calldata priceData
    ) external view returns (bool isManipulated, string memory reason);
    
    function analyzePricePattern(address asset, uint256[] calldata prices) external view returns (ManipulationData memory);
    function setManipulationConfig(address asset, ManipulationConfig calldata config) external;
    function getManipulationConfig(address asset) external view returns (ManipulationConfig memory);
    function getManipulationHistory(address asset) external view returns (ManipulationData[] memory);
    function reportFalsePositive(address asset, string calldata reason) external;
} 