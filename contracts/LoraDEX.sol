// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@uniswap/lib/contracts/libraries/FullMath.sol";

/**
 * @title LoraDEX
 * @dev DEX com AMM (Automated Market Maker) baseado em Uniswap V2
 */
contract LoraDEX is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // Constantes
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant SWAP_FEE = 3; // 0.3%
    uint256 public constant LIQUIDITY_FEE = 0; // 0% para liquidez
    
    // Variáveis de estado
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    bool public initialized;
    
    // Mapeamentos
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Eventos
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event FeeUpdated(uint256 newFee);
    
    // Modificadores
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "LoraDEX: EXPIRED");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Construtor vazio para permitir create2
    }
    
    /**
     * @dev Inicializa o par (chamado pelo factory)
     */
    function initialize(address _tokenA, address _tokenB) external {
        require(!initialized, "LoraDEX: ALREADY_INITIALIZED");
        require(_tokenA != _tokenB, "LoraDEX: IDENTICAL_ADDRESSES");
        require(_tokenA != address(0) && _tokenB != address(0), "LoraDEX: ZERO_ADDRESS");
        
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        initialized = true;
    }
    
    /**
     * @dev Adiciona liquidez ao pool
     */
    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = address(this);
        
        tokenA.safeTransferFrom(msg.sender, pair, amountA);
        tokenB.safeTransferFrom(msg.sender, pair, amountB);
        
        liquidity = mint(to);
    }
    
    /**
     * @dev Remove liquidez do pool
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 amountA, uint256 amountB) {
        address pair = address(this);
        
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = burn(to);
        require(amountA >= amountAMin, "LoraDEX: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "LoraDEX: INSUFFICIENT_B_AMOUNT");
    }
    
    /**
     * @dev Realiza swap de tokens
     */
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "LoraDEX: INSUFFICIENT_OUTPUT_AMOUNT");
        require(to != address(tokenA) && to != address(tokenB), "LoraDEX: INVALID_TO");
        
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "LoraDEX: INSUFFICIENT_LIQUIDITY");
        
        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = address(tokenA);
            address _token1 = address(tokenB);
            require(to != _token0 && to != _token1, "LoraDEX: INVALID_TO");
            
            if (amount0Out > 0) tokenA.safeTransfer(to, amount0Out);
            if (amount1Out > 0) tokenB.safeTransfer(to, amount1Out);
            
            if (data.length > 0) {
                // Callback para integração com outros contratos
                // ILoraDEXCallee(to).loraDEXCall(msg.sender, amount0Out, amount1Out, data);
            }
            
            balance0 = tokenA.balanceOf(address(this));
            balance1 = tokenB.balanceOf(address(this));
        }
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "LoraDEX: INSUFFICIENT_INPUT_AMOUNT");
        
        {
            uint256 balance0Adjusted = balance0 * FEE_DENOMINATOR - amount0In * SWAP_FEE;
            uint256 balance1Adjusted = balance1 * FEE_DENOMINATOR - amount1In * SWAP_FEE;
            require(
                balance0Adjusted * balance1Adjusted >= _reserve0 * _reserve1 * (FEE_DENOMINATOR**2),
                "LoraDEX: K"
            );
        }
        
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    /**
     * @dev Calcula o preço de saída para um swap
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "LoraDEX: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "LoraDEX: INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev Calcula o preço de entrada para um swap
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountIn) {
        require(amountOut > 0, "LoraDEX: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "LoraDEX: INSUFFICIENT_LIQUIDITY");
        
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - SWAP_FEE);
        amountIn = (numerator / denominator) + 1;
    }
    
    /**
     * @dev Retorna as reservas atuais
     */
    function getReserves() public view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }
    
    // Funções internas
    function _addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LoraDEX: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "LoraDEX: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "LoraDEX: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "LoraDEX: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }
    
    function mint(address to) internal returns (uint256 liquidity) {
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 amountA = balanceA - _reserveA;
        uint256 amountB = balanceB - _reserveB;
        
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Babylonian.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amountA * _totalSupply) / _reserveA, (amountB * _totalSupply) / _reserveB);
        }
        require(liquidity > 0, "LoraDEX: INSUFFICIENT_LIQUIDITY_MINTED");
        
        _mint(to, liquidity);
        _update(balanceA, balanceB, _reserveA, _reserveB);
        emit Mint(msg.sender, amountA, amountB);
    }
    
    function burn(address to) internal returns (uint256 amountA, uint256 amountB) {
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        address _tokenA = address(tokenA);
        address _tokenB = address(tokenB);
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        
        uint256 _totalSupply = totalSupply;
        amountA = (liquidity * balanceA) / _totalSupply;
        amountB = (liquidity * balanceB) / _totalSupply;
        require(amountA > 0 && amountB > 0, "LoraDEX: INSUFFICIENT_LIQUIDITY_BURNED");
        
        _burn(address(this), liquidity);
        tokenA.safeTransfer(to, amountA);
        tokenB.safeTransfer(to, amountB);
        balanceA = tokenA.balanceOf(address(this));
        balanceB = tokenB.balanceOf(address(this));
        
        _update(balanceA, balanceB, _reserveA, _reserveB);
        emit Burn(msg.sender, amountA, amountB, to);
    }
    
    function _update(uint256 balanceA, uint256 balanceB, uint256 _reserveA, uint256 _reserveB) internal {
        require(balanceA <= type(uint112).max && balanceB <= type(uint112).max, "LoraDEX: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserveA = balanceA;
        reserveB = balanceB;
        emit Sync(balanceA, balanceB);
    }
    
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
    
    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
    
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }
    
    // Eventos
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
} 