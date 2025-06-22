// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoraBridge {
    struct BridgeConfig {
        uint256 chainId;
        address bridgeContract;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 fee;
        bool isActive;
        uint256 maxDailyVolume;
        uint256 currentDailyVolume;
        uint256 lastResetTime;
    }

    struct CrossChainSwap {
        address user;
        uint256 sourceChainId;
        uint256 targetChainId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        bytes32 swapId;
        uint256 timestamp;
        bool isCompleted;
        bool isCancelled;
        bytes proof;
    }

    struct LiquidityPool {
        uint256 chainId;
        address token;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 totalFees;
        uint256 lastUpdateTime;
    }

    struct BridgeRequest {
        bytes32 requestId;
        address user;
        uint256 sourceChainId;
        uint256 targetChainId;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool isProcessed;
        bytes proof;
    }

    // Events
    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed user,
        uint256 sourceChainId,
        uint256 targetChainId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    );

    event SwapCompleted(
        bytes32 indexed swapId,
        address indexed user,
        uint256 amountOut,
        uint256 fee
    );

    event SwapCancelled(
        bytes32 indexed swapId,
        address indexed user,
        string reason
    );

    event LiquidityAdded(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount
    );

    event LiquidityRemoved(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount
    );

    event BridgeRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 sourceChainId,
        uint256 targetChainId,
        address token,
        uint256 amount
    );

    event BridgeRequestProcessed(
        bytes32 indexed requestId,
        bool success,
        bytes result
    );

    // Core bridge functions
    function initiateSwap(
        uint256 targetChainId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external payable returns (bytes32 swapId);

    function completeSwap(
        bytes32 swapId,
        uint256 sourceChainId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient,
        bytes calldata proof
    ) external;

    function cancelSwap(bytes32 swapId, string calldata reason) external;

    // Liquidity management
    function addLiquidity(
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function removeLiquidity(
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function getLiquidityPool(
        uint256 chainId,
        address token
    ) external view returns (LiquidityPool memory);

    // Bridge requests
    function createBridgeRequest(
        uint256 targetChainId,
        address token,
        uint256 amount
    ) external payable returns (bytes32 requestId);

    function processBridgeRequest(
        bytes32 requestId,
        bytes calldata proof
    ) external;

    function getBridgeRequest(
        bytes32 requestId
    ) external view returns (BridgeRequest memory);

    // Configuration
    function setBridgeConfig(
        uint256 chainId,
        BridgeConfig calldata config
    ) external;

    function getBridgeConfig(
        uint256 chainId
    ) external view returns (BridgeConfig memory);

    function isChainSupported(
        uint256 chainId
    ) external view returns (bool);

    // Fee management
    function calculateBridgeFee(
        uint256 sourceChainId,
        uint256 targetChainId,
        uint256 amount
    ) external view returns (uint256 fee);

    function collectFees(
        uint256 chainId,
        address token
    ) external returns (uint256 amount);

    // Cross-chain swap queries
    function getCrossChainSwap(
        bytes32 swapId
    ) external view returns (CrossChainSwap memory);

    function getUserSwaps(
        address user
    ) external view returns (bytes32[] memory swapIds);

    function getPendingSwaps(
        uint256 chainId
    ) external view returns (bytes32[] memory swapIds);

    // Emergency functions
    function emergencyPause() external;
    function emergencyUnpause() external;
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external;

    // Validator functions
    function addValidator(address validator) external;
    function removeValidator(address validator) external;
    function isValidator(address account) external view returns (bool);

    // Statistics
    function getTotalVolume(
        uint256 chainId
    ) external view returns (uint256);

    function getDailyVolume(
        uint256 chainId
    ) external view returns (uint256);

    function getTotalFees(
        uint256 chainId
    ) external view returns (uint256);
} 