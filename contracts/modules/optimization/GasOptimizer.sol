// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GasOptimizer
 * @dev Otimizador de gas para L2s e operações em lote
 */
contract GasOptimizer is ReentrancyGuard, Ownable {
    
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
        bytes swapData;
    }
    
    struct BatchSwapResult {
        uint256[] amountsOut;
        uint256 totalGasUsed;
        uint256 gasRefund;
    }
    
    struct GasConfig {
        bool useCalldata;
        bool useBatchProcessing;
        bool useLazyLoading;
        uint256 maxBatchSize;
        uint256 gasRefundThreshold;
        uint256 gasPriceLimit;
    }
    
    GasConfig public gasConfig;
    mapping(address => uint256) public userGasRefunds;
    mapping(bytes32 => BatchSwapResult) public batchResults;
    
    uint256 public constant MAX_BATCH_SIZE = 10;
    uint256 public constant GAS_REFUND_THRESHOLD = 100000;
    uint256 public constant GAS_PER_SWAP = 150000;
    
    event BatchSwapExecuted(
        address indexed user,
        SwapParams[] swaps,
        uint256[] amountsOut,
        uint256 gasUsed,
        uint256 gasRefund
    );
    
    event GasRefundClaimed(
        address indexed user,
        uint256 amount
    );
    
    event GasConfigUpdated(GasConfig config);
    
    constructor() Ownable(msg.sender) {
        gasConfig = GasConfig({
            useCalldata: true,
            useBatchProcessing: true,
            useLazyLoading: true,
            maxBatchSize: 5,
            gasRefundThreshold: GAS_REFUND_THRESHOLD,
            gasPriceLimit: 100 gwei
        });
    }
    
    /**
     * @dev Executa múltiplos swaps em lote
     */
    function batchSwap(SwapParams[] calldata swaps)
        external
        nonReentrant
        returns (uint256[] memory amountsOut)
    {
        require(swaps.length > 0, "Empty batch");
        require(swaps.length <= gasConfig.maxBatchSize, "Batch too large");
        require(tx.gasprice <= gasConfig.gasPriceLimit, "Gas price too high");
        
        uint256 gasStart = gasleft();
        amountsOut = new uint256[](swaps.length);
        
        for (uint256 i = 0; i < swaps.length; i++) {
            SwapParams memory swap = swaps[i];
            
            // Validar parâmetros
            require(swap.tokenIn != address(0) && swap.tokenOut != address(0), "Invalid tokens");
            require(swap.amountIn > 0, "Invalid amount");
            require(swap.recipient != address(0), "Invalid recipient");
            
            // Executar swap (simplificado)
            amountsOut[i] = _executeSwap(swap);
        }
        
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasRefund = _calculateGasRefund(gasUsed, swaps.length);
        
        // Armazenar resultado
        bytes32 batchId = keccak256(abi.encodePacked(msg.sender, block.timestamp, swaps.length));
        batchResults[batchId] = BatchSwapResult({
            amountsOut: amountsOut,
            totalGasUsed: gasUsed,
            gasRefund: gasRefund
        });
        
        // Adicionar refund ao usuário
        if (gasRefund > 0) {
            userGasRefunds[msg.sender] += gasRefund;
        }
        
        emit BatchSwapExecuted(msg.sender, swaps, amountsOut, gasUsed, gasRefund);
        
        return amountsOut;
    }
    
    /**
     * @dev Executa swap individual otimizado
     */
    function optimizedSwap(SwapParams calldata swap)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(swap.tokenIn != address(0) && swap.tokenOut != address(0), "Invalid tokens");
        require(swap.amountIn > 0, "Invalid amount");
        require(swap.recipient != address(0), "Invalid recipient");
        require(tx.gasprice <= gasConfig.gasPriceLimit, "Gas price too high");
        
        uint256 gasStart = gasleft();
        
        amountOut = _executeSwap(swap);
        
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasRefund = _calculateGasRefund(gasUsed, 1);
        
        if (gasRefund > 0) {
            userGasRefunds[msg.sender] += gasRefund;
        }
        
        return amountOut;
    }
    
    /**
     * @dev Reivindica refund de gas
     */
    function claimGasRefund() external nonReentrant {
        uint256 refund = userGasRefunds[msg.sender];
        require(refund > 0, "No refund available");
        
        userGasRefunds[msg.sender] = 0;
        
        // Transferir ETH para o usuário
        (bool success, ) = msg.sender.call{value: refund}("");
        require(success, "Transfer failed");
        
        emit GasRefundClaimed(msg.sender, refund);
    }
    
    /**
     * @dev Atualiza configuração de gas
     */
    function updateGasConfig(GasConfig calldata config) external onlyOwner {
        require(config.maxBatchSize <= MAX_BATCH_SIZE, "Batch size too large");
        require(config.gasRefundThreshold > 0, "Invalid threshold");
        
        gasConfig = config;
        
        emit GasConfigUpdated(config);
    }
    
    /**
     * @dev Otimiza calldata
     */
    function optimizeCalldata(bytes calldata data) external pure returns (bytes memory optimized) {
        // Em produção, isso seria uma otimização real do calldata
        // Por exemplo, compactar dados, remover zeros desnecessários, etc.
        optimized = data;
    }
    
    /**
     * @dev Executa swap individual
     */
    function _executeSwap(SwapParams memory swap) internal returns (uint256 amountOut) {
        // Simulação de swap - em produção seria uma chamada real para o DEX
        amountOut = swap.amountIn * 99 / 100; // 1% fee
        
        // Em produção, isso seria uma chamada real para o DEX
        // Por enquanto, apenas simular o resultado
        // IERC20(swap.tokenIn).transferFrom(msg.sender, address(this), swap.amountIn);
        // IERC20(swap.tokenOut).transfer(swap.recipient, amountOut);
        
        return amountOut;
    }
    
    /**
     * @dev Calcula refund de gas
     */
    function _calculateGasRefund(uint256 gasUsed, uint256 swapCount) internal view returns (uint256 refund) {
        uint256 expectedGas = swapCount * GAS_PER_SWAP;
        
        if (gasUsed < expectedGas && gasUsed > gasConfig.gasRefundThreshold) {
            refund = (expectedGas - gasUsed) * tx.gasprice;
        }
        
        return refund;
    }
    
    /**
     * @dev Retorna refund disponível do usuário
     */
    function getGasRefund(address user) external view returns (uint256) {
        return userGasRefunds[user];
    }
    
    /**
     * @dev Retorna resultado de batch
     */
    function getBatchResult(bytes32 batchId) external view returns (BatchSwapResult memory) {
        return batchResults[batchId];
    }
    
    /**
     * @dev Estima gas para batch
     */
    function estimateBatchGas(SwapParams[] calldata swaps) external view returns (uint256 gasEstimate) {
        gasEstimate = swaps.length * GAS_PER_SWAP;
        return gasEstimate;
    }
    
    /**
     * @dev Verifica se batch é válido
     */
    function validateBatch(SwapParams[] calldata swaps) external pure returns (bool isValid, string memory reason) {
        if (swaps.length == 0) {
            return (false, "Empty batch");
        }
        
        if (swaps.length > MAX_BATCH_SIZE) {
            return (false, "Batch too large");
        }
        
        for (uint256 i = 0; i < swaps.length; i++) {
            if (swaps[i].tokenIn == address(0) || swaps[i].tokenOut == address(0)) {
                return (false, "Invalid tokens");
            }
            
            if (swaps[i].amountIn == 0) {
                return (false, "Invalid amount");
            }
            
            if (swaps[i].recipient == address(0)) {
                return (false, "Invalid recipient");
            }
        }
        
        return (true, "");
    }
    
    /**
     * @dev Retorna configuração atual
     */
    function getGasConfig() external view returns (GasConfig memory) {
        return gasConfig;
    }
    
    // Função para receber ETH
    receive() external payable {}
} 