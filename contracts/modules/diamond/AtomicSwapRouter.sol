// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUnifiedPool {
    function removeLiquidity(address token, uint256 amount) external;
    function addLiquidity(address token, uint256 amount) external;
}

interface ILoraBridgeManager {
    function sendCrossChainMessage(bytes calldata data, uint256 dstChainId) external;
}

contract AtomicSwapRouter {
    address public owner;
    address public pool;
    address public bridgeManager;

    struct Swap {
        address user;
        address token;
        uint256 amount;
        bytes32 hashlock;
        uint256 timelock;
        bool completed;
    }
    mapping(bytes32 => Swap) public swaps;

    event SwapInitiated(bytes32 indexed swapId, address indexed user, address token, uint256 amount, bytes32 hashlock, uint256 timelock, uint256 dstChainId);
    event SwapRedeemed(bytes32 indexed swapId, bytes32 preimage);
    event SwapRefunded(bytes32 indexed swapId);
    event CrossChainSwapReceived(bytes32 indexed swapId, address user, address token, uint256 amount, uint256 srcChainId);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyBridgeManager() { require(msg.sender == bridgeManager, "Not bridgeManager"); _; }

    constructor(address _pool, address _bridgeManager) { owner = msg.sender; pool = _pool; bridgeManager = _bridgeManager; }

    function initiateSwap(address token, uint256 amount, bytes32 hashlock, uint256 timelock, uint256 dstChainId) external {
        IUnifiedPool(pool).removeLiquidity(token, amount);
        bytes32 swapId = keccak256(abi.encodePacked(msg.sender, token, amount, hashlock, timelock, dstChainId, block.timestamp));
        swaps[swapId] = Swap(msg.sender, token, amount, hashlock, timelock, false);
        bytes memory data = abi.encodeWithSignature("receiveCrossChainSwap(bytes32,address,address,uint256)", swapId, msg.sender, token, amount);
        ILoraBridgeManager(bridgeManager).sendCrossChainMessage(data, dstChainId);
        emit SwapInitiated(swapId, msg.sender, token, amount, hashlock, timelock, dstChainId);
    }

    function redeemSwap(bytes32 swapId, bytes32 preimage) external {
        Swap storage s = swaps[swapId];
        require(!s.completed, "Already completed");
        require(keccak256(abi.encodePacked(preimage)) == s.hashlock, "Invalid preimage");
        s.completed = true;
        IUnifiedPool(pool).addLiquidity(s.token, s.amount);
        emit SwapRedeemed(swapId, preimage);
    }

    function refundSwap(bytes32 swapId) external {
        Swap storage s = swaps[swapId];
        require(!s.completed, "Already completed");
        require(block.timestamp > s.timelock, "Timelock not expired");
        s.completed = true;
        // Refund logic (e.g., return tokens to user)
        emit SwapRefunded(swapId);
    }

    function receiveCrossChainSwap(bytes32 swapId, address user, address token, uint256 amount, uint256 srcChainId) external onlyBridgeManager {
        swaps[swapId] = Swap(user, token, amount, 0, 0, false);
        IUnifiedPool(pool).addLiquidity(token, amount);
        emit CrossChainSwapReceived(swapId, user, token, amount, srcChainId);
    }
} 