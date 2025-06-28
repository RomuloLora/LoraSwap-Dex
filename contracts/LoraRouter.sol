// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LoraFactory.sol";
import "./LoraDEX.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LoraRouter
 * @dev Router para facilitar operações no DEX
 */
contract LoraRouter is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    LoraFactory public immutable factory;
    address public immutable WETH;
    
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "LoraRouter: EXPIRED");
        _;
    }
    
    constructor(address _factory, address _WETH) Ownable(msg.sender) {
        factory = LoraFactory(_factory);
        WETH = _WETH;
    }
    
    /**
     * @dev Adiciona liquidez para dois tokens
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        require(deadline >= block.timestamp, 'LoraRouter: EXPIRED');
        
        // Transfer tokens from user to router first
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);
        
        // Approve factory to spend tokens
        IERC20(tokenA).approve(address(factory), amountADesired);
        IERC20(tokenB).approve(address(factory), amountBDesired);
        
        // Get pair address
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), 'LoraRouter: PAIR_NOT_FOUND');
        
        // Transfer tokens to pair
        IERC20(tokenA).transfer(pair, amountADesired);
        IERC20(tokenB).transfer(pair, amountBDesired);
        
        // Add liquidity to pair
        (amountA, amountB, liquidity) = LoraDEX(pair).addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
        
        // Transfer any excess tokens back to user
        if (amountA < amountADesired) {
            IERC20(tokenA).transfer(msg.sender, amountADesired - amountA);
        }
        if (amountB < amountBDesired) {
            IERC20(tokenB).transfer(msg.sender, amountBDesired - amountB);
        }
    }
    
    /**
     * @dev Remove liquidez
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "LoraRouter: PAIR_NOT_FOUND");
        
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = LoraDEX(pair).removeLiquidity(liquidity, amountAMin, amountBMin, to, deadline);
        require(amountA >= amountAMin, "LoraRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "LoraRouter: INSUFFICIENT_B_AMOUNT");
    }
    
    /**
     * @dev Swap exato de entrada
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, 'LoraRouter: EXPIRED');
        require(path.length >= 2, 'LoraRouter: INVALID_PATH');
        
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        // Transfer input tokens from user to router
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        
        for (uint i = 0; i < path.length - 1; i++) {
            address pair = factory.getPair(path[i], path[i + 1]);
            require(pair != address(0), 'LoraRouter: PAIR_NOT_FOUND');
            
            // Approve pair to spend tokens
            IERC20(path[i]).approve(pair, amounts[i]);
            
            // Transfer tokens to pair
            IERC20(path[i]).transfer(pair, amounts[i]);
            
            // Calculate expected output
            uint amountOut = LoraDEX(pair).getAmountOut(amounts[i], IERC20(path[i]).balanceOf(pair), IERC20(path[i + 1]).balanceOf(pair));
            amounts[i + 1] = amountOut;
            
            // Perform swap
            LoraDEX(pair).swap(
                0,
                amountOut,
                address(this),
                ""
            );
        }
        
        // Transfer final tokens to user
        IERC20(path[path.length - 1]).transfer(to, amounts[amounts.length - 1]);
    }
    
    /**
     * @dev Swap exato de saída
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "LoraRouter: EXCESSIVE_INPUT_AMOUNT");
        
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amounts[0]);
        _swap(amounts, path, to);
    }
    
    /**
     * @dev Calcula montantes de saída
     */
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "LoraRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i; i < path.length - 1; i++) {
            address pair = factory.getPair(path[i], path[i + 1]);
            require(pair != address(0), "LoraRouter: PAIR_NOT_FOUND");
            
            (uint256 reserveIn, uint256 reserveOut) = getReserves(pair, path[i], path[i + 1]);
            amounts[i + 1] = LoraDEX(pair).getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    
    /**
     * @dev Calcula montantes de entrada
     */
    function getAmountsIn(uint256 amountOut, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "LoraRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint256 i = path.length - 1; i > 0; i--) {
            address pair = factory.getPair(path[i - 1], path[i]);
            require(pair != address(0), "LoraRouter: PAIR_NOT_FOUND");
            
            (uint256 reserveIn, uint256 reserveOut) = getReserves(pair, path[i - 1], path[i]);
            amounts[i - 1] = LoraDEX(pair).getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
    
    /**
     * @dev Obtém reservas de um par
     */
    function getReserves(address pair, address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (uint256 reserve0, uint256 reserve1) = LoraDEX(pair).getReserves();
        (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    /**
     * @dev Executa swap interno
     */
    function _swap(uint256[] memory amounts, address[] memory path, address to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to_ = i < path.length - 2 ? factory.getPair(output, path[i + 2]) : to;
            
            LoraDEX(factory.getPair(input, output)).swap(amount0Out, amount1Out, to_, "");
        }
    }
    
    /**
     * @dev Ordena tokens
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
    
    /**
     * @dev Resgata tokens perdidos
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
} 