// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract LoraDEX is ReentrancyGuard, Pausable, Ownable {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Configurações de segurança
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant FEE_NUMERATOR = 3; // 0.3% fee
    
    // Eventos
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event EmergencyWithdraw(address indexed owner, address token, uint256 amount);
    
    // Modificadores
    modifier validTokens(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        _;
    }
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        _;
    }
    
    modifier sufficientReserves(uint256 reserveIn, uint256 reserveOut) {
        require(reserveIn > 0 && reserveOut > 0, "Insufficient reserves");
        _;
    }
    
    constructor(address _tokenA, address _tokenB) 
        validTokens(_tokenA, _tokenB)
        Ownable(msg.sender)
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    /**
     * @dev Adiciona liquidez ao pool
     * @param amountA Quantidade do token A
     * @param amountB Quantidade do token B
     * @param minLiquidity Liquidez mínima esperada (proteção contra slippage)
     */
    function addLiquidity(
        uint256 amountA, 
        uint256 amountB, 
        uint256 minLiquidity
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(amountA) 
        validAmount(amountB)
        returns (uint256 liquidity)
    {
        // Verificar se os tokens foram transferidos com sucesso
        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Token A transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "Token B transfer failed"
        );
        
        // Calcular liquidez baseada na proporção dos tokens
        if (reserveA == 0 && reserveB == 0) {
            liquidity = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity >= minLiquidity, "Insufficient liquidity minted");
        } else {
            uint256 liquidityA = amountA * reserveB / reserveA;
            uint256 liquidityB = amountB * reserveA / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            require(liquidity >= minLiquidity, "Insufficient liquidity minted");
        }
        
        // Atualizar reservas
        reserveA += amountA;
        reserveB += amountB;
        
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Remove liquidez do pool
     * @param liquidity Quantidade de liquidez a remover
     * @param minAmountA Quantidade mínima do token A esperada
     * @param minAmountB Quantidade mínima do token B esperada
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minAmountA,
        uint256 minAmountB
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(liquidity)
        returns (uint256 amountA, uint256 amountB)
    {
        require(reserveA > 0 && reserveB > 0, "Insufficient reserves");
        
        // Calcular proporção da liquidez
        uint256 totalLiquidity = sqrt(reserveA * reserveB);
        amountA = liquidity * reserveA / totalLiquidity;
        amountB = liquidity * reserveB / totalLiquidity;
        
        require(amountA >= minAmountA && amountB >= minAmountB, "Insufficient output amounts");
        
        // Atualizar reservas
        reserveA -= amountA;
        reserveB -= amountB;
        
        // Transferir tokens
        require(tokenA.transfer(msg.sender, amountA), "Token A transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "Token B transfer failed");
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Calcula o valor de saída para um swap
     * @param amountIn Quantidade de entrada
     * @param reserveIn Reserva do token de entrada
     * @param reserveOut Reserva do token de saída
     * @return amountOut Quantidade de saída
     */
    function getAmountOut(
        uint256 amountIn, 
        uint256 reserveIn, 
        uint256 reserveOut
    ) 
        public 
        pure 
        validAmount(amountIn)
        sufficientReserves(reserveIn, reserveOut)
        returns (uint256 amountOut) 
    {
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
        
        require(amountOut > 0, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");
    }
    
    /**
     * @dev Executa um swap de tokens
     * @param tokenIn Endereço do token de entrada
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída esperada
     */
    function swap(
        address tokenIn, 
        uint256 amountIn, 
        uint256 minAmountOut
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(amountIn)
    {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        IERC20 tokenInContract = IERC20(tokenIn);
        IERC20 tokenOutContract = tokenIn == address(tokenA) ? tokenB : tokenA;
        
        uint256 reserveIn = tokenIn == address(tokenA) ? reserveA : reserveB;
        uint256 reserveOut = tokenIn == address(tokenA) ? reserveB : reserveA;
        
        require(reserveIn > 0 && reserveOut > 0, "Insufficient reserves");
        
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        
        // Proteção contra slippage
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
        // Verificar se o usuário aprovou o gasto
        require(
            tokenInContract.allowance(msg.sender, address(this)) >= amountIn,
            "Insufficient allowance"
        );
        
        // Transferir tokens
        require(
            tokenInContract.transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );
        require(
            tokenOutContract.transfer(msg.sender, amountOut),
            "Transfer failed"
        );
        
        // Atualizar reservas
        if (tokenIn == address(tokenA)) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }
        
        uint256 fee = amountIn * FEE_NUMERATOR / FEE_DENOMINATOR;
        emit Swap(msg.sender, tokenIn, address(tokenOutContract), amountIn, amountOut, fee);
    }
    
    /**
     * @dev Função de emergência para retirar tokens (apenas owner)
     * @param token Endereço do token
     * @param amount Quantidade a retirar
     */
    function emergencyWithdraw(address token, uint256 amount) 
        external 
        onlyOwner 
        whenPaused
    {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20 tokenContract = IERC20(token);
        require(
            tokenContract.transfer(owner(), amount),
            "Transfer failed"
        );
        
        emit EmergencyWithdraw(owner(), token, amount);
    }
    
    /**
     * @dev Pausa o contrato (apenas owner)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Despausa o contrato (apenas owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Calcula a raiz quadrada usando o método de Newton
     * @param x Número para calcular a raiz quadrada
     * @return y Raiz quadrada
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    /**
     * @dev Retorna as reservas atuais
     * @return _reserveA Reserva do token A
     * @return _reserveB Reserva do token B
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }
    
    /**
     * @dev Verifica se o contrato tem liquidez suficiente
     * @return bool Verdadeiro se há liquidez suficiente
     */
    function hasLiquidity() external view returns (bool) {
        return reserveA > 0 && reserveB > 0;
    }
} 