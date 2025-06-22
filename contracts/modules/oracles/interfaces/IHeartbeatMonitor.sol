// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHeartbeatMonitor
 * @dev Interface para monitoramento de heartbeat dos oracles
 */
interface IHeartbeatMonitor {
    
    struct HeartbeatConfig {
        uint256 interval;
        uint256 tolerance;
        uint256 lastHeartbeat;
        bool isActive;
        uint256 missedHeartbeats;
        uint256 totalHeartbeats;
    }
    
    // Eventos
    event HeartbeatReceived(address indexed oracle, uint256 timestamp);
    event HeartbeatMissed(address indexed oracle, uint256 expectedTime, uint256 actualTime);
    event OracleMarkedInactive(address indexed oracle, string reason);
    event OracleReactivated(address indexed oracle);
    
    // Funções principais
    function registerOracle(address oracle, uint256 interval, uint256 tolerance) external;
    function unregisterOracle(address oracle) external;
    function updateHeartbeat(address oracle) external;
    function checkHeartbeat(address oracle) external view returns (bool isAlive, uint256 lastHeartbeat);
    function getHeartbeatConfig(address oracle) external view returns (HeartbeatConfig memory);
    function getInactiveOracles() external view returns (address[] memory);
    function isOracleActive(address oracle) external view returns (bool);
} 