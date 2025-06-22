// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../modules/TWAPOracle.sol";
import "../modules/BatchAuction.sol";
import "../modules/CommitReveal.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// Interfaces para módulos plugáveis
interface IOracle {
    function getPrice(address pool, address tokenIn, address tokenOut) external view returns (uint256 price, uint256 lastUpdated);
}

interface IPool {
    function onSwap(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) external;
    function onAddLiquidity(address user, uint256 amountA, uint256 amountB) external;
    function onRemoveLiquidity(address user, uint256 amountA, uint256 amountB) external;
}

interface IRewards {
    function onSwapReward(address user, uint256 amountIn, uint256 amountOut) external;
    function onLiquidityReward(address user, uint256 liquidity) external;
}

interface IGovernance {
    function isActionAllowed(address user, bytes4 selector) external view returns (bool);
}

contract LoraDEX is ReentrancyGuard, Pausable, Ownable {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Proteções MEV
    TWAPOracle public twapOracle;
    BatchAuction public batchAuction;
    CommitReveal public commitReveal;
    
    // Configurações de segurança
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant FEE_NUMERATOR = 3; // 0.3% fee
    
    // Configurações MEV
    bool public useTWAP = true;
    bool public useBatchAuction = false;
    bool public useCommitReveal = false;
    uint256 public maxSlippage = 500; // 5% (500 basis points)
    uint256 public minGasPrice = 0;
    uint256 public maxGasPrice = type(uint256).max;
    
    // Hooks configuráveis
    IOracle public externalOracle;
    IPool public externalPool;
    IRewards public rewardsModule;
    IGovernance public governanceModule;
    
    // Eventos
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event EmergencyWithdraw(address indexed owner, address token, uint256 amount);
    event MEVProtectionEnabled(string protection, bool enabled);
    event SlippageProtectionTriggered(address indexed user, uint256 expectedAmount, uint256 actualAmount);
    event ModuleSet(string module, address indexed moduleAddress);
    
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
    
    modifier validGasPrice() {
        require(tx.gasprice >= minGasPrice && tx.gasprice <= maxGasPrice, "Invalid gas price");
        _;
    }
    
    modifier onlyGovernanceOrOwner() {
        require(msg.sender == owner() || (address(governanceModule) != address(0) && governanceModule.isActionAllowed(msg.sender, msg.sig)), "Not allowed");
        _;
    }
    
    constructor(
        address _tokenA, 
        address _tokenB,
        address _twapOracle,
        address _batchAuction,
        address _commitReveal
    ) 
        validTokens(_tokenA, _tokenB)
        Ownable(msg.sender)
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        
        // Configurar proteções MEV
        if (_twapOracle != address(0)) {
            twapOracle = TWAPOracle(_twapOracle);
        }
        if (_batchAuction != address(0)) {
            batchAuction = BatchAuction(_batchAuction);
        }
        if (_commitReveal != address(0)) {
            commitReveal = CommitReveal(_commitReveal);
        }
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
        
        // Atualizar TWAP Oracle se habilitado
        if (useTWAP && address(twapOracle) != address(0)) {
            uint256 priceA = (reserveB * 1e18) / reserveA;
            uint256 priceB = (reserveA * 1e18) / reserveB;
            twapOracle.addObservation(address(this), priceA, priceB);
        }
        
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
        
        // Atualizar TWAP Oracle se habilitado
        if (useTWAP && address(twapOracle) != address(0)) {
            uint256 priceA = (reserveB * 1e18) / reserveA;
            uint256 priceB = (reserveA * 1e18) / reserveB;
            twapOracle.addObservation(address(this), priceA, priceB);
        }
        
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
     * @dev Executa um swap de tokens com proteção MEV
     * @param tokenIn Endereço do token de entrada
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída esperada
     * @param useMEVProtection Se deve usar proteções MEV
     */
    function swap(
        address tokenIn, 
        uint256 amountIn, 
        uint256 minAmountOut,
        bool useMEVProtection
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(amountIn)
        validGasPrice
    {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        IERC20 tokenInContract = IERC20(tokenIn);
        IERC20 tokenOutContract = tokenIn == address(tokenA) ? tokenB : tokenA;
        
        uint256 reserveIn = tokenIn == address(tokenA) ? reserveA : reserveB;
        uint256 reserveOut = tokenIn == address(tokenA) ? reserveB : reserveA;
        
        require(reserveIn > 0 && reserveOut > 0, "Insufficient reserves");
        
        // Verificar se o usuário aprovou o gasto
        require(
            tokenInContract.allowance(msg.sender, address(this)) >= amountIn,
            "Insufficient allowance"
        );
        
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        
        // Proteção MEV
        if (useMEVProtection) {
            amountOut = _applyMEVProtection(tokenIn, amountIn, amountOut, reserveIn, reserveOut);
        }
        
        // Proteção contra slippage
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
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
        
        // Atualizar TWAP Oracle se habilitado
        if (useTWAP && address(twapOracle) != address(0)) {
            uint256 priceA = (reserveB * 1e18) / reserveA;
            uint256 priceB = (reserveA * 1e18) / reserveB;
            twapOracle.addObservation(address(this), priceA, priceB);
        }
        
        _afterSwap(msg.sender, tokenIn, address(tokenOutContract), amountIn, amountOut);
        
        uint256 fee = amountIn * FEE_NUMERATOR / FEE_DENOMINATOR;
        emit Swap(msg.sender, tokenIn, address(tokenOutContract), amountIn, amountOut, fee);
    }
    
    /**
     * @dev Aplica proteções MEV
     * @param tokenIn Token de entrada
     * @param amountIn Quantidade de entrada
     * @param amountOut Quantidade de saída calculada
     * @param reserveIn Reserva de entrada
     * @param reserveOut Reserva de saída
     * @return adjustedAmountOut Quantidade ajustada
     */
    function _applyMEVProtection(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 adjustedAmountOut) {
        adjustedAmountOut = amountOut;
        
        // TWAP Protection
        if (useTWAP && address(twapOracle) != address(0)) {
            uint256 currentPrice = (reserveOut * 1e18) / reserveIn;
            uint256 twapPrice = _getTWAPPrice(tokenIn);
            
            if (twapPrice > 0) {
                uint256 deviation = _calculateDeviation(currentPrice, twapPrice);
                
                if (deviation > maxSlippage) {
                    // Usar preço TWAP para calcular amountOut
                    adjustedAmountOut = (amountIn * twapPrice) / 1e18;
                    adjustedAmountOut = adjustedAmountOut * (FEE_DENOMINATOR - FEE_NUMERATOR) / FEE_DENOMINATOR;
                }
            }
        }
        
        return adjustedAmountOut;
    }
    
    /**
     * @dev Obtém preço TWAP
     * @param tokenIn Token de entrada
     * @return twapPrice Preço TWAP
     */
    function _getTWAPPrice(address tokenIn) internal view returns (uint256 twapPrice) {
        try twapOracle.getTWAP(address(this), 1800) returns (uint256 twap0, uint256 twap1) {
            if (tokenIn == address(tokenA)) {
                twapPrice = twap1; // Preço do token B em relação ao A
            } else {
                twapPrice = twap0; // Preço do token A em relação ao B
            }
        } catch {
            twapPrice = 0;
        }
    }
    
    /**
     * @dev Calcula desvio percentual
     * @param current Valor atual
     * @param twap Valor TWAP
     * @return deviation Desvio em basis points
     */
    function _calculateDeviation(
        uint256 current,
        uint256 twap
    ) internal pure returns (uint256 deviation) {
        if (twap == 0) return 0;
        
        if (current > twap) {
            deviation = ((current - twap) * 10000) / twap;
        } else {
            deviation = ((twap - current) * 10000) / twap;
        }
        
        return deviation;
    }
    
    /**
     * @dev Submete ordem para batch auction
     * @param tokenIn Token de entrada
     * @param tokenOut Token de saída
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída
     * @param maxGasPriceParam Preço máximo de gas
     * @param swapData Dados do swap
     */
    function submitBatchOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxGasPriceParam,
        bytes calldata swapData
    ) external whenNotPaused {
        require(useBatchAuction && address(batchAuction) != address(0), "Batch auction not enabled");
        
        batchAuction.submitOrder(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            maxGasPriceParam,
            swapData
        );
    }
    
    /**
     * @dev Submete commit para commit-reveal
     * @param commitHash Hash do commit
     */
    function submitCommit(bytes32 commitHash) external whenNotPaused {
        require(useCommitReveal && address(commitReveal) != address(0), "Commit-reveal not enabled");
        
        commitReveal.submitCommit(commitHash);
    }
    
    /**
     * @dev Revela commit
     * @param tokenIn Token de entrada
     * @param tokenOut Token de saída
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída
     * @param nonce Nonce único
     * @param secret Secret usado para gerar o commit
     */
    function revealCommit(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 nonce,
        bytes32 secret
    ) external whenNotPaused {
        require(useCommitReveal && address(commitReveal) != address(0), "Commit-reveal not enabled");
        
        commitReveal.revealCommit(tokenIn, tokenOut, amountIn, minAmountOut, nonce, secret);
    }
    
    /**
     * @dev Executa swap via commit-reveal
     * @param commitHash Hash do commit
     */
    function executeCommitSwap(bytes32 commitHash) external whenNotPaused {
        require(useCommitReveal && address(commitReveal) != address(0), "Commit-reveal not enabled");
        
        commitReveal.executeSwap(commitHash);
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
     * @dev Atualiza configurações MEV
     * @param _useTWAP Se deve usar TWAP
     * @param _useBatchAuction Se deve usar batch auction
     * @param _useCommitReveal Se deve usar commit-reveal
     * @param _maxSlippage Novo slippage máximo
     * @param _minGasPrice Novo gas price mínimo
     * @param _maxGasPrice Novo gas price máximo
     */
    function updateMEVConfig(
        bool _useTWAP,
        bool _useBatchAuction,
        bool _useCommitReveal,
        uint256 _maxSlippage,
        uint256 _minGasPrice,
        uint256 _maxGasPrice
    ) external onlyOwner {
        useTWAP = _useTWAP;
        useBatchAuction = _useBatchAuction;
        useCommitReveal = _useCommitReveal;
        maxSlippage = _maxSlippage;
        minGasPrice = _minGasPrice;
        maxGasPrice = _maxGasPrice;
        
        emit MEVProtectionEnabled("TWAP", _useTWAP);
        emit MEVProtectionEnabled("BatchAuction", _useBatchAuction);
        emit MEVProtectionEnabled("CommitReveal", _useCommitReveal);
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
    
    /**
     * @dev Retorna configurações MEV
     * @return _useTWAP Se usa TWAP
     * @return _useBatchAuction Se usa batch auction
     * @return _useCommitReveal Se usa commit-reveal
     * @return _maxSlippage Slippage máximo
     * @return _minGasPrice Gas price mínimo
     * @return _maxGasPrice Gas price máximo
     */
    function getMEVConfig() external view returns (
        bool _useTWAP,
        bool _useBatchAuction,
        bool _useCommitReveal,
        uint256 _maxSlippage,
        uint256 _minGasPrice,
        uint256 _maxGasPrice
    ) {
        return (
            useTWAP,
            useBatchAuction,
            useCommitReveal,
            maxSlippage,
            minGasPrice,
            maxGasPrice
        );
    }

    // Funções para setar módulos externos (apenas owner/governança)
    function setOracle(address oracle) external onlyOwner {
        externalOracle = IOracle(oracle);
        emit ModuleSet("Oracle", oracle);
    }
    function setPoolModule(address pool) external onlyOwner {
        externalPool = IPool(pool);
        emit ModuleSet("Pool", pool);
    }
    function setRewardsModule(address rewards) external onlyOwner {
        rewardsModule = IRewards(rewards);
        emit ModuleSet("Rewards", rewards);
    }
    function setGovernanceModule(address gov) external onlyOwner {
        governanceModule = IGovernance(gov);
        emit ModuleSet("Governance", gov);
    }

    // Exemplo de uso de hooks em swap
    function _afterSwap(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) internal {
        if (address(externalPool) != address(0)) {
            externalPool.onSwap(user, tokenIn, tokenOut, amountIn, amountOut);
        }
        if (address(rewardsModule) != address(0)) {
            rewardsModule.onSwapReward(user, amountIn, amountOut);
        }
    }

    // Placeholder para emergency pause por multisig/governança
    function emergencyPause() external onlyGovernanceOrOwner {
        _pause();
    }
    function emergencyUnpause() external onlyGovernanceOrOwner {
        _unpause();
    }

    /// @notice Este contrato é modular e preparado para integração com oracles, pools, rewards, governança, upgrades e extensões futuras.
    /// @dev Consulte os eventos ModuleSet e as funções set*Module para ativar/desativar módulos plugáveis.
} 