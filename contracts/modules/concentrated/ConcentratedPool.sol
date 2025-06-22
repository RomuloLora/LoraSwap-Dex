// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TickMath.sol";
import "../../interfaces/ILoraDEX.sol";

/**
 * @title ConcentratedPool
 * @dev Pool com concentrated liquidity baseado no Uniswap V3
 */
contract ConcentratedPool is ReentrancyGuard, Ownable {
    using TickMath for int24;

    // Token addresses
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    // Pool state
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint8 feeProtocol;
        bool unlocked;
    }

    struct Position {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct Tick {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        int56 tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32 secondsOutside;
        bool initialized;
    }

    Slot0 public slot0;
    uint128 public liquidity;
    mapping(int24 => Tick) public ticks;
    mapping(bytes32 => Position) public positions;

    // Oracle state
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        bool initialized;
    }
    Observation[65535] public observations;

    // Events
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    event Mint(
        address indexed sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    // Modifiers
    modifier onlyValidTicks(int24 tickLower, int24 tickUpper) {
        require(TickMath.isValidTick(tickLower, fee), "Invalid tick lower");
        require(TickMath.isValidTick(tickUpper, fee), "Invalid tick upper");
        require(tickLower < tickUpper, "Invalid tick range");
        _;
    }

    modifier onlyValidPrice(uint160 sqrtPriceX96) {
        require(sqrtPriceX96 >= TickMath.MIN_SQRT_RATIO, "Price too low");
        require(sqrtPriceX96 <= TickMath.MAX_SQRT_RATIO, "Price too high");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        uint24 _fee
    ) Ownable(msg.sender) {
        require(_token0 != _token1, "Same tokens");
        require(_token0 < _token1, "Token order");
        
        token0 = _token0;
        token1 = _token1;
        fee = _fee;

        // Initialize slot0
        slot0.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        slot0.tick = 0;
        slot0.observationIndex = 0;
        slot0.observationCardinality = 1;
        slot0.observationCardinalityNext = 1;
        slot0.feeProtocol = 0;
        slot0.unlocked = true;
    }

    /**
     * @dev Mint liquidity position
     */
    function mint(ILoraDEX.MintParams calldata params)
        external
        nonReentrant
        onlyValidTicks(params.tickLower, params.tickUpper)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.amount > 0, "Invalid amount");
        require(params.recipient != address(0), "Invalid recipient");

        // Calculate amounts
        (amount0, amount1) = _getAmountsForLiquidity(
            slot0.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(params.tickLower),
            TickMath.getSqrtRatioAtTick(params.tickUpper),
            params.amount
        );

        // Transfer tokens
        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        }

        // Update position
        bytes32 positionKey = keccak256(abi.encodePacked(params.recipient, params.tickLower, params.tickUpper));
        Position storage position = positions[positionKey];
        
        position.owner = params.recipient;
        position.tickLower = params.tickLower;
        position.tickUpper = params.tickUpper;
        position.liquidity += params.amount;

        // Update ticks
        _updateTick(params.tickLower, params.amount, true);
        _updateTick(params.tickUpper, params.amount, false);

        // Update global liquidity
        liquidity += params.amount;

        emit Mint(msg.sender, params.recipient, params.tickLower, params.tickUpper, params.amount, amount0, amount1);
    }

    /**
     * @dev Burn liquidity position
     */
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    )
        external
        nonReentrant
        onlyValidTicks(tickLower, tickUpper)
        returns (uint256 amount0, uint256 amount1)
    {
        require(amount > 0, "Invalid amount");

        bytes32 positionKey = keccak256(abi.encodePacked(msg.sender, tickLower, tickUpper));
        Position storage position = positions[positionKey];
        
        require(position.owner == msg.sender, "Not owner");
        require(position.liquidity >= amount, "Insufficient liquidity");

        // Calculate amounts
        (amount0, amount1) = _getAmountsForLiquidity(
            slot0.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            amount
        );

        // Update position
        position.liquidity -= amount;

        // Update ticks
        _updateTick(tickLower, amount, false);
        _updateTick(tickUpper, amount, true);

        // Update global liquidity
        liquidity -= amount;

        // Transfer tokens
        if (amount0 > 0) {
            IERC20(token0).transfer(msg.sender, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transfer(msg.sender, amount1);
        }

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    /**
     * @dev Execute swap
     */
    function swap(ILoraDEX.SwapParams calldata params)
        external
        nonReentrant
        onlyValidPrice(params.sqrtPriceLimitX96)
        returns (int256 amount0, int256 amount1)
    {
        require(params.amountSpecified != 0, "Invalid amount");
        require(params.recipient != address(0), "Invalid recipient");

        // Execute swap logic
        (amount0, amount1) = _executeSwap(params);

        // Update oracle
        _updateOracle();

        emit Swap(msg.sender, params.recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    /**
     * @dev Flash loan
     */
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external nonReentrant {
        require(recipient != address(0), "Invalid recipient");

        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        // Transfer tokens
        if (amount0 > 0) {
            IERC20(token0).transfer(recipient, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transfer(recipient, amount1);
        }

        // Call flash callback
        ILoraFlashCallback(msg.sender).loraFlashCallback(amount0, amount1, data);

        uint256 balance0After = IERC20(token0).balanceOf(address(this));
        uint256 balance1After = IERC20(token1).balanceOf(address(this));

        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

    /**
     * @dev Get amounts for liquidity
     */
    function _getAmountsForLiquidity(
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtPriceX96 <= sqrtRatioAX96) {
            amount0 = _getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtPriceX96 >= sqrtRatioBX96) {
            amount1 = _getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else {
            amount0 = _getLiquidityForAmount0(sqrtPriceX96, sqrtRatioBX96, liquidity);
            amount1 = _getLiquidityForAmount1(sqrtRatioAX96, sqrtPriceX96, liquidity);
        }
    }

    /**
     * @dev Get liquidity for amount0
     */
    function _getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        uint256 numerator = uint256(liquidity) << 96;
        uint256 denominator = sqrtRatioBX96 - sqrtRatioAX96;
        amount0 = numerator / denominator;
    }

    /**
     * @dev Get liquidity for amount1
     */
    function _getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        amount1 = uint256(liquidity) * (sqrtRatioBX96 - sqrtRatioAX96) >> 96;
    }

    /**
     * @dev Execute swap logic
     */
    function _executeSwap(ILoraDEX.SwapParams calldata params) internal returns (int256 amount0, int256 amount1) {
        // Simplified swap implementation
        // In a full implementation, this would include:
        // - Price calculation
        // - Tick crossing
        // - Fee calculation
        // - Liquidity updates
        
        amount0 = params.amountSpecified;
        amount1 = -int256(uint256(amount0) * fee / 1000000); // Simplified fee calculation
    }

    /**
     * @dev Update tick
     */
    function _updateTick(int24 tick, uint128 liquidityDelta, bool isUpper) internal {
        Tick storage tickData = ticks[tick];
        
        if (!tickData.initialized) {
            tickData.initialized = true;
        }
        
        if (isUpper) {
            tickData.liquidityGross += liquidityDelta;
            tickData.liquidityNet -= int128(liquidityDelta);
        } else {
            tickData.liquidityGross += liquidityDelta;
            tickData.liquidityNet += int128(liquidityDelta);
        }
    }

    /**
     * @dev Update oracle
     */
    function _updateOracle() internal {
        uint16 observationIndex = slot0.observationIndex;
        uint16 observationCardinality = slot0.observationCardinality;
        
        observations[observationIndex] = Observation({
            blockTimestamp: uint32(block.timestamp),
            tickCumulative: int56(slot0.tick),
            initialized: true
        });
        
        slot0.observationIndex = (observationIndex + 1) % observationCardinality;
    }

    // View functions
    function getPosition(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (Position memory) {
        bytes32 positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper));
        return positions[positionKey];
    }

    function getTick(int24 tick) external view returns (Tick memory) {
        return ticks[tick];
    }
}

interface ILoraFlashCallback {
    function loraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
} 