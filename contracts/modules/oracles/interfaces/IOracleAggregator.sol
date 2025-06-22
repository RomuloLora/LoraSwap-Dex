// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracleAggregator
 * @dev Interface para o sistema de oracles agregados
 */
interface IOracleAggregator {
    
    struct OracleConfig {
        string name;
        uint256 heartbeatInterval;
        uint256 deviationThreshold;
        bool isFallback;
        bool isActive;
        uint256 lastHeartbeat;
        uint256 totalUpdates;
        uint256 totalDeviations;
    }
    
    struct PriceData {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        bool isValid;
    }
    
    struct AggregatedPrice {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 oracleCount;
        bool isValid;
    }
    
    // Eventos
    event OracleAdded(address indexed oracle, string name, uint256 heartbeatInterval);
    event OracleRemoved(address indexed oracle);
    event OracleAuthorized(address indexed oracle, bool authorized);
    event AssetWhitelisted(address indexed asset, bool whitelisted);
    event PriceUpdated(address indexed asset, address indexed oracle, uint256 price, uint256 timestamp);
    event PriceAggregated(address indexed asset, uint256 price, uint256 confidence, uint256 timestamp);
    event DeviationDetected(address indexed asset, address indexed oracle, uint256 deviation);
    event ManipulationDetected(address indexed asset, address indexed oracle, string reason);
    event HeartbeatMissed(address indexed oracle, uint256 lastHeartbeat);
    event FallbackActivated(address indexed asset, address indexed fallbackOracle);
    event EmergencyPaused(address indexed asset, string reason);
    
    // Funções principais
    function addOracle(
        address oracle,
        string calldata name,
        uint256 heartbeatInterval,
        uint256 deviationThreshold,
        bool isFallback
    ) external;
    
    function removeOracle(address oracle) external;
    function updatePrice(address asset, uint256 price, uint256 confidence) external;
    function getPrice(address asset) external view returns (uint256 price, uint256 confidence, uint256 timestamp);
    function getPriceData(address asset) external view returns (AggregatedPrice memory);
    function getOracleConfig(address oracle) external view returns (OracleConfig memory);
    function getOraclePrice(address asset, address oracle) external view returns (PriceData memory);
    function getSystemStats() external view returns (
        uint256 totalOracles,
        uint256 totalAssets,
        uint256 totalPriceUpdates,
        uint256 totalDeviationsDetected,
        uint256 totalManipulationsDetected
    );
} 