// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDeviationChecker
 * @dev Interface para verificação de desvios de preço
 */
interface IDeviationChecker {
    
    struct DeviationConfig {
        uint256 maxDeviationPercent;
        uint256 minDeviationPercent;
        uint256 deviationWindow;
        bool isEnabled;
    }
    
    struct DeviationData {
        uint256 currentPrice;
        uint256 previousPrice;
        uint256 deviation;
        uint256 timestamp;
        bool isSignificant;
    }
    
    // Eventos
    event DeviationDetected(address indexed asset, uint256 deviation, uint256 threshold);
    event DeviationThresholdUpdated(address indexed asset, uint256 newThreshold);
    event DeviationWindowUpdated(address indexed asset, uint256 newWindow);
    
    // Funções principais
    function calculateDeviation(uint256 currentPrice, uint256 previousPrice) external pure returns (uint256 deviation);
    function isDeviationSignificant(uint256 deviation, uint256 threshold) external pure returns (bool);
    function checkPriceDeviation(address asset, uint256 newPrice) external view returns (DeviationData memory);
    function setDeviationConfig(address asset, DeviationConfig calldata config) external;
    function getDeviationConfig(address asset) external view returns (DeviationConfig memory);
    function getDeviationHistory(address asset) external view returns (DeviationData[] memory);
} 