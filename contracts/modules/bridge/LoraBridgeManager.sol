// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridge {
    function sendMessage(bytes calldata data, uint256 dstChainId) external;
    function receiveMessage(bytes calldata data, uint256 srcChainId) external;
}

interface ISecureBridge {
    function proposeMessage(bytes calldata data) external;
    function executeMessage(bytes calldata data) external;
    function verifyMessage(bytes calldata data, address[] calldata sigs) external view returns (bool);
}

contract LoraBridgeManager {
    address public owner;
    mapping(uint256 => address) public bridges; // chainId => bridge
    mapping(uint256 => address) public secureBridges; // chainId => secureBridge
    mapping(address => bool) public relayers;
    mapping(bytes32 => bool) public processedMessages;

    event BridgeSet(uint256 indexed chainId, address bridge);
    event SecureBridgeSet(uint256 indexed chainId, address secureBridge);
    event RelayerSet(address relayer, bool enabled);
    event MessageSent(uint256 indexed dstChainId, bytes data);
    event MessageReceived(uint256 indexed srcChainId, bytes data);
    event SecureMessageProposed(uint256 indexed dstChainId, bytes32 msgHash);
    event SecureMessageExecuted(uint256 indexed dstChainId, bytes32 msgHash);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyRelayer() { require(relayers[msg.sender], "Not relayer"); _; }

    constructor() { owner = msg.sender; }

    function setBridge(uint256 chainId, address bridge) external onlyOwner {
        bridges[chainId] = bridge;
        emit BridgeSet(chainId, bridge);
    }

    function setSecureBridge(uint256 chainId, address secureBridge) external onlyOwner {
        secureBridges[chainId] = secureBridge;
        emit SecureBridgeSet(chainId, secureBridge);
    }

    function setRelayer(address relayer, bool enabled) external onlyOwner {
        relayers[relayer] = enabled;
        emit RelayerSet(relayer, enabled);
    }

    // Bridge tradicional (sem multi-sig)
    function sendCrossChainMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        require(bridges[dstChainId] != address(0), "No bridge");
        IBridge(bridges[dstChainId]).sendMessage(data, dstChainId);
        emit MessageSent(dstChainId, data);
    }

    // Bridge segura (com multi-sig e time-lock)
    function sendSecureCrossChainMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        require(secureBridges[dstChainId] != address(0), "No secure bridge");
        ISecureBridge(secureBridges[dstChainId]).proposeMessage(data);
        bytes32 msgHash = keccak256(data);
        emit SecureMessageProposed(dstChainId, msgHash);
    }

    // Executar mensagem segura após time-lock
    function executeSecureMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        require(secureBridges[dstChainId] != address(0), "No secure bridge");
        ISecureBridge(secureBridges[dstChainId]).executeMessage(data);
        bytes32 msgHash = keccak256(data);
        emit SecureMessageExecuted(dstChainId, msgHash);
    }

    // Verificar mensagem segura
    function verifySecureMessage(bytes calldata data, address[] calldata sigs, uint256 chainId) external view returns (bool) {
        require(secureBridges[chainId] != address(0), "No secure bridge");
        return ISecureBridge(secureBridges[chainId]).verifyMessage(data, sigs);
    }

    function receiveCrossChainMessage(bytes calldata data, uint256 srcChainId) external {
        require(msg.sender == bridges[srcChainId], "Invalid bridge");
        bytes32 msgHash = keccak256(data);
        require(!processedMessages[msgHash], "Already processed");
        processedMessages[msgHash] = true;
        emit MessageReceived(srcChainId, data);
        // Lógica de roteamento para contratos destino
    }

    function receiveSecureCrossChainMessage(bytes calldata data, uint256 srcChainId, address[] calldata sigs) external {
        require(msg.sender == secureBridges[srcChainId], "Invalid secure bridge");
        require(verifySecureMessage(data, sigs, srcChainId), "Invalid signatures");
        bytes32 msgHash = keccak256(data);
        require(!processedMessages[msgHash], "Already processed");
        processedMessages[msgHash] = true;
        emit MessageReceived(srcChainId, data);
        // Lógica de roteamento para contratos destino
    }
} 