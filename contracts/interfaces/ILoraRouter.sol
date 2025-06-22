// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoraRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    struct Route {
        address[] pools;
        address[] tokens;
        uint24[] fees;
        uint256[] amounts;
    }

    struct RouterConfig {
        uint256 maxHops;
        uint256 maxSlippage;
        bool useSplitRoutes;
        uint256 gasLimit;
        bool useMEVProtection;
    }

    // Events
    event SwapExecuted(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event RouteOptimized(
        address indexed user,
        Route route,
        uint256 gasUsed,
        uint256 amountOut
    );

    event SplitRouteExecuted(
        address indexed user,
        Route[] routes,
        uint256 totalAmountIn,
        uint256 totalAmountOut
    );

    // Core swap functions
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        returns (uint256 amountIn);

    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        returns (uint256 amountIn);

    // Quote functions
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    function quoteExactInput(bytes calldata path, uint256 amountIn)
        external
        returns (uint256 amountOut);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);

    function quoteExactOutput(bytes calldata path, uint256 amountOut)
        external
        returns (uint256 amountIn);

    // Multi-hop functions
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        RouterConfig calldata config
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline,
        RouterConfig calldata config
    ) external returns (uint256[] memory amounts);

    // Split route functions
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        RouterConfig calldata config
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        RouterConfig calldata config
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        RouterConfig calldata config
    ) external;

    // Route optimization
    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        RouterConfig calldata config
    ) external view returns (Route memory optimalRoute);

    function findSplitRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        RouterConfig calldata config
    ) external view returns (Route[] memory routes);

    // Gas optimization
    function estimateGasForSwap(
        ExactInputSingleParams calldata params
    ) external view returns (uint256 gasEstimate);

    function batchSwap(
        ExactInputSingleParams[] calldata params
    ) external payable returns (uint256[] memory amountsOut);

    // Configuration
    function setRouterConfig(RouterConfig calldata config) external;
    function getRouterConfig() external view returns (RouterConfig memory);
} 