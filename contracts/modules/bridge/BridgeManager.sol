// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/ILoraBridge.sol";

/**
 * @title BridgeManager
 * @dev Gerenciador de bridges cross-chain
 */
contract BridgeManager is ReentrancyGuard, Ownable {
    
    mapping(uint256 => ILoraBridge.BridgeConfig) public bridgeConfigs;
    mapping(bytes32 => ILoraBridge.CrossChainSwap) public crossChainSwaps;
    mapping(uint256 => ILoraBridge.LiquidityPool) public liquidityPools;
    mapping(address => bool) public validators;
    
    uint256 public validatorCount;
    uint256 public constant MIN_VALIDATORS = 3;
    uint256 public constant MAX_VALIDATORS = 21;
    
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
    
    event LiquidityAdded(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount
    );
    
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    
    modifier onlyValidator() {
        require(validators[msg.sender], "Not validator");
        _;
    }
    
    modifier validChain(uint256 chainId) {
        require(bridgeConfigs[chainId].isActive, "Chain not supported");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Inicia swap cross-chain
     */
    function initiateSwap(
        uint256 targetChainId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external payable validChain(targetChainId) returns (bytes32 swapId) {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid tokens");
        require(amountIn > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");
        
        ILoraBridge.BridgeConfig memory config = bridgeConfigs[targetChainId];
        require(amountIn >= config.minAmount && amountIn <= config.maxAmount, "Amount out of range");
        
        // Verificar liquidez disponível
        ILoraBridge.LiquidityPool memory pool = liquidityPools[targetChainId];
        require(pool.availableLiquidity >= amountIn, "Insufficient liquidity");
        
        // Calcular fee
        uint256 fee = _calculateBridgeFee(block.chainid, targetChainId, amountIn);
        require(msg.value >= fee, "Insufficient fee");
        
        // Gerar swap ID
        swapId = keccak256(abi.encodePacked(
            msg.sender,
            block.chainid,
            targetChainId,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            block.timestamp
        ));
        
        // Criar swap
        crossChainSwaps[swapId] = ILoraBridge.CrossChainSwap({
            user: msg.sender,
            sourceChainId: block.chainid,
            targetChainId: targetChainId,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            swapId: swapId,
            timestamp: block.timestamp,
            isCompleted: false,
            isCancelled: false,
            proof: ""
        });
        
        // Transferir tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Atualizar liquidez
        pool.availableLiquidity -= amountIn;
        liquidityPools[targetChainId] = pool;
        
        emit SwapInitiated(swapId, msg.sender, block.chainid, targetChainId, tokenIn, tokenOut, amountIn, minAmountOut);
        
        return swapId;
    }
    
    /**
     * @dev Completa swap cross-chain
     */
    function completeSwap(
        bytes32 swapId,
        uint256 sourceChainId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient,
        bytes calldata proof
    ) external onlyValidator validChain(sourceChainId) {
        ILoraBridge.CrossChainSwap storage swap = crossChainSwaps[swapId];
        require(swap.user != address(0), "Swap not found");
        require(!swap.isCompleted, "Swap already completed");
        require(!swap.isCancelled, "Swap cancelled");
        require(swap.sourceChainId == sourceChainId, "Invalid source chain");
        
        // Verificar prova (simplificado)
        require(_verifyProof(swapId, proof), "Invalid proof");
        
        // Marcar como completado
        swap.isCompleted = true;
        swap.proof = proof;
        
        // Transferir tokens para o destinatário
        IERC20(tokenOut).transfer(recipient, amountOut);
        
        // Atualizar estatísticas
        ILoraBridge.LiquidityPool storage pool = liquidityPools[sourceChainId];
        pool.totalFees += _calculateBridgeFee(sourceChainId, block.chainid, amountIn);
        
        emit SwapCompleted(swapId, recipient, amountOut, _calculateBridgeFee(sourceChainId, block.chainid, amountIn));
    }
    
    /**
     * @dev Adiciona liquidez para bridge
     */
    function addLiquidity(
        uint256 chainId,
        address token,
        uint256 amount
    ) external validChain(chainId) {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");
        
        ILoraBridge.LiquidityPool storage pool = liquidityPools[chainId];
        pool.chainId = chainId;
        pool.token = token;
        pool.totalLiquidity += amount;
        pool.availableLiquidity += amount;
        pool.lastUpdateTime = block.timestamp;
        
        // Transferir tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        emit LiquidityAdded(chainId, token, msg.sender, amount);
    }
    
    /**
     * @dev Configura bridge para uma chain
     */
    function setBridgeConfig(
        uint256 chainId,
        ILoraBridge.BridgeConfig calldata config
    ) external onlyOwner {
        require(config.bridgeContract != address(0), "Invalid bridge contract");
        require(config.minAmount <= config.maxAmount, "Invalid amount range");
        
        bridgeConfigs[chainId] = config;
    }
    
    /**
     * @dev Adiciona validador
     */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator");
        require(!validators[validator], "Already validator");
        require(validatorCount < MAX_VALIDATORS, "Too many validators");
        
        validators[validator] = true;
        validatorCount++;
        
        emit ValidatorAdded(validator);
    }
    
    /**
     * @dev Remove validador
     */
    function removeValidator(address validator) external onlyOwner {
        require(validators[validator], "Not validator");
        require(validatorCount > MIN_VALIDATORS, "Too few validators");
        
        validators[validator] = false;
        validatorCount--;
        
        emit ValidatorRemoved(validator);
    }
    
    /**
     * @dev Calcula fee do bridge
     */
    function _calculateBridgeFee(
        uint256 sourceChainId,
        uint256 targetChainId,
        uint256 amount
    ) internal view returns (uint256 fee) {
        ILoraBridge.BridgeConfig memory config = bridgeConfigs[targetChainId];
        fee = amount * config.fee / 1000000; // Fee em basis points
        return fee;
    }
    
    /**
     * @dev Verifica prova (simplificado)
     */
    function _verifyProof(bytes32 swapId, bytes calldata proof) internal pure returns (bool) {
        // Em produção, isso seria uma verificação criptográfica real
        return proof.length > 0;
    }
    
    /**
     * @dev Retorna configuração do bridge
     */
    function getBridgeConfig(uint256 chainId) external view returns (ILoraBridge.BridgeConfig memory) {
        return bridgeConfigs[chainId];
    }
    
    /**
     * @dev Retorna swap cross-chain
     */
    function getCrossChainSwap(bytes32 swapId) external view returns (ILoraBridge.CrossChainSwap memory) {
        return crossChainSwaps[swapId];
    }
    
    /**
     * @dev Retorna pool de liquidez
     */
    function getLiquidityPool(uint256 chainId) external view returns (ILoraBridge.LiquidityPool memory) {
        return liquidityPools[chainId];
    }
    
    /**
     * @dev Verifica se é validador
     */
    function isValidator(address account) external view returns (bool) {
        return validators[account];
    }
    
    /**
     * @dev Retorna estatísticas
     */
    function getTotalVolume(uint256 chainId) external view returns (uint256) {
        return liquidityPools[chainId].totalFees;
    }
} 