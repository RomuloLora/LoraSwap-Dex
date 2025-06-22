// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IHeartbeatMonitor.sol";

/**
 * @title HeartbeatMonitor
 * @dev Monitoramento de heartbeat dos oracles com otimizações de gas
 */
contract HeartbeatMonitor is IHeartbeatMonitor, Ownable, ReentrancyGuard {
    
    // Struct otimizado para packing
    struct HeartbeatConfigPacked {
        uint64 interval;            // 8 bytes
        uint64 tolerance;           // 8 bytes
        uint64 lastHeartbeat;       // 8 bytes
        uint32 missedHeartbeats;    // 4 bytes
        uint32 totalHeartbeats;     // 4 bytes
        uint8 flags;                // 1 byte: bit 0 = isActive
    }
    
    // Batch operations
    struct BatchHeartbeatUpdate {
        address oracle;
        uint64 timestamp;
    }
    
    mapping(address => HeartbeatConfigPacked) public heartbeatConfigs;
    mapping(address => bool) public registeredOracles;
    address[] public oracleList;
    
    // Contadores em um slot
    struct MonitoringStats {
        uint64 totalOracles;
        uint64 activeOracles;
        uint64 totalHeartbeats;
        uint64 totalMissedHeartbeats;
    }
    MonitoringStats public monitoringStats;
    
    constructor() Ownable(msg.sender) {}
    
    modifier onlyRegisteredOracle() {
        require(registeredOracles[msg.sender], "Oracle not registered");
        _;
    }
    
    /**
     * @dev Registra um oracle para monitoramento (otimizado)
     */
    function registerOracle(
        address oracle,
        uint256 interval,
        uint256 tolerance
    ) external override onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(interval > 0, "Invalid interval");
        require(tolerance <= interval, "Tolerance too high");
        require(!registeredOracles[oracle], "Oracle already registered");
        
        heartbeatConfigs[oracle] = HeartbeatConfigPacked({
            interval: uint64(interval),
            tolerance: uint64(tolerance),
            lastHeartbeat: uint64(block.timestamp),
            missedHeartbeats: 0,
            totalHeartbeats: 0,
            flags: 1 // isActive = true
        });
        
        registeredOracles[oracle] = true;
        oracleList.push(oracle);
        monitoringStats.totalOracles++;
        monitoringStats.activeOracles++;
        
        emit OracleAdded(oracle, "", interval);
    }
    
    /**
     * @dev Remove oracle do monitoramento (otimizado)
     */
    function unregisterOracle(address oracle) external override onlyOwner {
        require(registeredOracles[oracle], "Oracle not registered");
        
        delete heartbeatConfigs[oracle];
        registeredOracles[oracle] = false;
        
        // Remover da lista usando assembly para otimização
        uint256 length = oracleList.length;
        for (uint256 i = 0; i < length;) {
            if (oracleList[i] == oracle) {
                // Mover último elemento para posição atual
                oracleList[i] = oracleList[length - 1];
                oracleList.pop();
                break;
            }
            unchecked { i++; }
        }
        
        if ((heartbeatConfigs[oracle].flags & 1) != 0) {
            monitoringStats.activeOracles--;
        }
        monitoringStats.totalOracles--;
    }
    
    /**
     * @dev Atualiza heartbeat de um oracle (otimizado com assembly)
     */
    function updateHeartbeat(address oracle) external override onlyRegisteredOracle {
        HeartbeatConfigPacked storage config = heartbeatConfigs[oracle];
        require((config.flags & 1) != 0, "Oracle inactive"); // bit 0 = isActive
        
        uint256 expectedTime;
        uint256 currentTimestamp = block.timestamp;
        
        // Verificar se o heartbeat está atrasado usando assembly
        assembly {
            let configSlot := config.slot
            let configValue := sload(configSlot)
            
            // Extrair interval e lastHeartbeat
            let interval := shr(192, configValue)
            let lastHeartbeat := shr(128, and(configValue, shl(128, 0xFFFFFFFFFFFFFFFF)))
            expectedTime := add(lastHeartbeat, interval)
        }
        
        // Verificar se o heartbeat está atrasado
        if (currentTimestamp > expectedTime + config.tolerance) {
            // Incrementar missedHeartbeats usando assembly
            assembly {
                let configSlot := config.slot
                let configValue := sload(configSlot)
                let missedHeartbeats := add(shr(160, and(configValue, shl(160, 0xFFFFFFFF))), 1)
                let missedMask := shl(160, 0xFFFFFFFF)
                configValue := and(configValue, not(missedMask))
                configValue := or(configValue, shl(160, missedHeartbeats))
                sstore(configSlot, configValue)
            }
            
            monitoringStats.totalMissedHeartbeats++;
            emit HeartbeatMissed(oracle, expectedTime, currentTimestamp);
            
            // Marcar como inativo se muitos heartbeats perdidos
            if (config.missedHeartbeats >= 3) {
                assembly {
                    let configSlot := config.slot
                    let configValue := sload(configSlot)
                    // Limpar bit isActive
                    configValue := and(configValue, not(1))
                    sstore(configSlot, configValue)
                }
                monitoringStats.activeOracles--;
                emit OracleMarkedInactive(oracle, "Too many missed heartbeats");
            }
        } else {
            // Resetar contador de heartbeats perdidos se no prazo
            if (config.missedHeartbeats > 0) {
                assembly {
                    let configSlot := config.slot
                    let configValue := sload(configSlot)
                    // Resetar missedHeartbeats
                    let missedMask := shl(160, 0xFFFFFFFF)
                    configValue := and(configValue, not(missedMask))
                    sstore(configSlot, configValue)
                }
            }
        }
        
        // Atualizar lastHeartbeat e totalHeartbeats usando assembly
        assembly {
            let configSlot := config.slot
            let configValue := sload(configSlot)
            
            // Atualizar lastHeartbeat (bits 128-191)
            let newTimestamp := shl(128, currentTimestamp)
            let timestampMask := shl(128, 0xFFFFFFFFFFFFFFFF)
            configValue := and(configValue, not(timestampMask))
            configValue := or(configValue, newTimestamp)
            
            // Incrementar totalHeartbeats (bits 160-191)
            let totalHeartbeats := add(shr(160, and(configValue, shl(160, 0xFFFFFFFF))), 1)
            let heartbeatsMask := shl(160, 0xFFFFFFFF)
            configValue := and(configValue, not(heartbeatsMask))
            configValue := or(configValue, shl(160, totalHeartbeats))
            
            sstore(configSlot, configValue)
        }
        
        monitoringStats.totalHeartbeats++;
        emit HeartbeatReceived(oracle, currentTimestamp);
    }
    
    /**
     * @dev Batch update heartbeats (otimização para múltiplos updates)
     */
    function batchUpdateHeartbeats(BatchHeartbeatUpdate[] calldata updates) external onlyRegisteredOracle {
        uint256 length = updates.length;
        require(length <= 20, "Too many updates"); // Limite para evitar timeout
        
        uint256 currentTimestamp = block.timestamp;
        
        for (uint256 i = 0; i < length;) {
            BatchHeartbeatUpdate calldata update = updates[i];
            
            if (registeredOracles[update.oracle]) {
                HeartbeatConfigPacked storage config = heartbeatConfigs[update.oracle];
                
                if ((config.flags & 1) != 0) { // isActive
                    // Atualizar heartbeat usando assembly
                    assembly {
                        let configSlot := config.slot
                        let configValue := sload(configSlot)
                        
                        // Atualizar lastHeartbeat
                        let newTimestamp := shl(128, update.timestamp)
                        let timestampMask := shl(128, 0xFFFFFFFFFFFFFFFF)
                        configValue := and(configValue, not(timestampMask))
                        configValue := or(configValue, newTimestamp)
                        
                        // Incrementar totalHeartbeats
                        let totalHeartbeats := add(shr(160, and(configValue, shl(160, 0xFFFFFFFF))), 1)
                        let heartbeatsMask := shl(160, 0xFFFFFFFF)
                        configValue := and(configValue, not(heartbeatsMask))
                        configValue := or(configValue, shl(160, totalHeartbeats))
                        
                        sstore(configSlot, configValue)
                    }
                    
                    emit HeartbeatReceived(update.oracle, update.timestamp);
                }
            }
            
            unchecked { i++; }
        }
        
        monitoringStats.totalHeartbeats += uint64(length);
    }
    
    /**
     * @dev Verifica se um oracle está vivo (otimizado)
     */
    function checkHeartbeat(address oracle) external view override returns (bool isAlive, uint256 lastHeartbeat) {
        if (!registeredOracles[oracle]) {
            return (false, 0);
        }
        
        HeartbeatConfigPacked storage config = heartbeatConfigs[oracle];
        uint256 expectedTime;
        
        // Calcular expectedTime usando assembly
        assembly {
            let configSlot := config.slot
            let configValue := sload(configSlot)
            let interval := shr(192, configValue)
            let lastHeartbeatValue := shr(128, and(configValue, shl(128, 0xFFFFFFFFFFFFFFFF)))
            expectedTime := add(lastHeartbeatValue, interval)
        }
        
        isAlive = (config.flags & 1) != 0 && currentTimestamp <= expectedTime + config.tolerance;
        lastHeartbeat = config.lastHeartbeat;
    }
    
    /**
     * @dev Retorna configuração de heartbeat de um oracle (lazy loading)
     */
    function getHeartbeatConfig(address oracle) external view override returns (HeartbeatConfig memory) {
        HeartbeatConfigPacked storage packed = heartbeatConfigs[oracle];
        
        return HeartbeatConfig({
            interval: packed.interval,
            tolerance: packed.tolerance,
            lastHeartbeat: packed.lastHeartbeat,
            isActive: (packed.flags & 1) != 0,
            missedHeartbeats: packed.missedHeartbeats,
            totalHeartbeats: packed.totalHeartbeats
        });
    }
    
    /**
     * @dev Retorna lista de oracles inativos (otimizado)
     */
    function getInactiveOracles() external view override returns (address[] memory) {
        uint256 inactiveCount = monitoringStats.totalOracles - monitoringStats.activeOracles;
        address[] memory inactive = new address[](inactiveCount);
        uint256 count = 0;
        
        uint256 length = oracleList.length;
        for (uint256 i = 0; i < length && count < inactiveCount;) {
            address oracle = oracleList[i];
            if (registeredOracles[oracle] && (heartbeatConfigs[oracle].flags & 1) == 0) {
                inactive[count] = oracle;
                count++;
            }
            unchecked { i++; }
        }
        
        return inactive;
    }
    
    /**
     * @dev Verifica se um oracle está ativo (otimizado)
     */
    function isOracleActive(address oracle) external view override returns (bool) {
        if (!registeredOracles[oracle]) {
            return false;
        }
        
        HeartbeatConfigPacked storage config = heartbeatConfigs[oracle];
        uint256 expectedTime;
        
        assembly {
            let configSlot := config.slot
            let configValue := sload(configSlot)
            let interval := shr(192, configValue)
            let lastHeartbeat := shr(128, and(configValue, shl(128, 0xFFFFFFFFFFFFFFFF)))
            expectedTime := add(lastHeartbeat, interval)
        }
        
        return (config.flags & 1) != 0 && currentTimestamp <= expectedTime + config.tolerance;
    }
    
    /**
     * @dev Reativa um oracle inativo (otimizado)
     */
    function reactivateOracle(address oracle) external onlyOwner {
        require(registeredOracles[oracle], "Oracle not registered");
        require((heartbeatConfigs[oracle].flags & 1) == 0, "Oracle already active");
        
        // Ativar oracle usando assembly
        assembly {
            let configSlot := heartbeatConfigs[oracle].slot
            let configValue := sload(configSlot)
            // Setar bit isActive
            configValue := or(configValue, 1)
            sstore(configSlot, configValue)
        }
        
        // Resetar missedHeartbeats
        heartbeatConfigs[oracle].missedHeartbeats = 0;
        monitoringStats.activeOracles++;
        
        emit OracleReactivated(oracle);
    }
    
    /**
     * @dev Retorna estatísticas do monitoramento (otimizado)
     */
    function getMonitoringStats() external view returns (
        uint256 _totalOracles,
        uint256 _activeOracles,
        uint256 _totalHeartbeats,
        uint256 _totalMissedHeartbeats
    ) {
        return (
            monitoringStats.totalOracles,
            monitoringStats.activeOracles,
            monitoringStats.totalHeartbeats,
            monitoringStats.totalMissedHeartbeats
        );
    }
    
    /**
     * @dev Retorna lista de todos os oracles registrados
     */
    function getAllOracles() external view returns (address[] memory) {
        return oracleList;
    }
} 