// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @dev Interface para oracles de preço individuais
 */
interface IPriceOracle {
    
    struct PriceFeed {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 decimals;
        string description;
    }
    
    // Eventos
    event PriceUpdated(address indexed asset, uint256 price, uint256 confidence, uint256 timestamp);
    event OraclePaused(address indexed oracle, string reason);
    event OracleResumed(address indexed oracle);
    
    // Funções principais
    function getPrice(address asset) external view returns (uint256 price, uint256 confidence);
    function getPriceFeed(address asset) external view returns (PriceFeed memory);
    function updatePrice(address asset, uint256 price, uint256 confidence) external;
    function isPriceValid(address asset) external view returns (bool);
    function getLastUpdateTime(address asset) external view returns (uint256);
    function getSupportedAssets() external view returns (address[] memory);
} 