// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoraBridgeManager {
    function sendCrossChainMessage(bytes calldata data, uint256 dstChainId) external;
    function sendSecureCrossChainMessage(bytes calldata data, uint256 dstChainId) external;
    function executeSecureMessage(bytes calldata data, uint256 dstChainId) external;
}

contract CrossChainRelayer {
    address public owner;
    address public bridgeManager;
    mapping(address => bool) public relayers;
    mapping(bytes32 => bool) public relayedMessages;
    uint256 public relayFee;

    event RelayerSet(address indexed relayer, bool enabled);
    event MessageRelayed(bytes32 indexed msgHash, uint256 indexed dstChainId);
    event RelayFeeSet(uint256 fee);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyRelayer() { require(relayers[msg.sender], "Not relayer"); _; }

    constructor(address _bridgeManager) { owner = msg.sender; bridgeManager = _bridgeManager; }

    function setRelayer(address relayer, bool enabled) external onlyOwner {
        relayers[relayer] = enabled;
        emit RelayerSet(relayer, enabled);
    }

    function setRelayFee(uint256 fee) external onlyOwner {
        relayFee = fee;
        emit RelayFeeSet(fee);
    }

    // Relayer para bridge tradicional
    function relayMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        bytes32 msgHash = keccak256(abi.encodePacked(data, dstChainId));
        require(!relayedMessages[msgHash], "Already relayed");
        relayedMessages[msgHash] = true;
        ILoraBridgeManager(bridgeManager).sendCrossChainMessage(data, dstChainId);
        emit MessageRelayed(msgHash, dstChainId);
    }

    // Relayer para bridge segura
    function relaySecureMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        bytes32 msgHash = keccak256(abi.encodePacked(data, dstChainId));
        require(!relayedMessages[msgHash], "Already relayed");
        relayedMessages[msgHash] = true;
        ILoraBridgeManager(bridgeManager).sendSecureCrossChainMessage(data, dstChainId);
        emit MessageRelayed(msgHash, dstChainId);
    }

    // Executar mensagem segura após time-lock
    function executeSecureMessage(bytes calldata data, uint256 dstChainId) external onlyRelayer {
        ILoraBridgeManager(bridgeManager).executeSecureMessage(data, dstChainId);
    }

    // Verificar se mensagem foi relayada
    function isMessageRelayed(bytes calldata data, uint256 dstChainId) external view returns (bool) {
        bytes32 msgHash = keccak256(abi.encodePacked(data, dstChainId));
        return relayedMessages[msgHash];
    }
} 