// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoraBridgeManager {
    function sendCrossChainMessage(bytes calldata data, uint256 dstChainId) external;
}

contract UnifiedPool {
    address public owner;
    address public bridgeManager;
    mapping(address => uint256) public globalLiquidity; // token => total
    mapping(address => mapping(address => uint256)) public userLiquidity; // user => token => amount
    mapping(address => uint256) public lastSyncTimestamp; // token => timestamp

    event LiquidityAdded(address indexed user, address indexed token, uint256 amount);
    event LiquidityRemoved(address indexed user, address indexed token, uint256 amount);
    event CrossChainSync(address indexed token, uint256 amount, uint256 dstChainId);
    event LiquiditySynced(address indexed token, uint256 newTotal, uint256 srcChainId);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyBridgeManager() { require(msg.sender == bridgeManager, "Not bridgeManager"); _; }

    constructor(address _bridgeManager) { owner = msg.sender; bridgeManager = _bridgeManager; }

    function addLiquidity(address token, uint256 amount) external {
        // TransferFrom omitted for brevity
        userLiquidity[msg.sender][token] += amount;
        globalLiquidity[token] += amount;
        emit LiquidityAdded(msg.sender, token, amount);
    }

    function removeLiquidity(address token, uint256 amount) external {
        require(userLiquidity[msg.sender][token] >= amount, "Insufficient");
        userLiquidity[msg.sender][token] -= amount;
        globalLiquidity[token] -= amount;
        emit LiquidityRemoved(msg.sender, token, amount);
    }

    function syncLiquidityToChain(address token, uint256 dstChainId) external onlyOwner {
        bytes memory data = abi.encodeWithSignature("syncLiquidity(address,uint256)", token, globalLiquidity[token]);
        ILoraBridgeManager(bridgeManager).sendCrossChainMessage(data, dstChainId);
        emit CrossChainSync(token, globalLiquidity[token], dstChainId);
    }

    function receiveLiquiditySync(address token, uint256 newTotal, uint256 srcChainId) external onlyBridgeManager {
        globalLiquidity[token] = newTotal;
        lastSyncTimestamp[token] = block.timestamp;
        emit LiquiditySynced(token, newTotal, srcChainId);
    }
} 