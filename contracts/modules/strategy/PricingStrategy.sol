// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PricingStrategy
 * @dev Strategy Pattern para diferentes algoritmos de pricing
 */
contract PricingStrategy is ReentrancyGuard, Ownable {
    
    struct PricingConfig {
        string strategyName;
        address strategyContract;
        bool isActive;
        uint256 weight;
        uint256 lastUpdateTime;
        string description;
    }
    
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        string source;
    }
    
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
        string strategy;
    }
    
    mapping(string => PricingConfig) public strategies;
    mapping(address => mapping(address => PriceData)) public priceFeeds;
    mapping(address => bool) public authorizedStrategies;
    mapping(string => address) public strategyContracts;
    
    string[] public strategyNames;
    uint256 public totalStrategies;
    
    event StrategyRegistered(string indexed name, address indexed strategyContract, string description);
    event StrategyUpdated(string indexed name, address indexed strategyContract);
    event StrategyDeactivated(string indexed name);
    event PriceUpdated(address indexed token0, address indexed token1, uint256 price, string source);
    event SwapExecuted(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        string strategy
    );
    
    modifier onlyAuthorizedStrategy() {
        require(authorizedStrategies[msg.sender], "Not authorized strategy");
        _;
    }
    
    modifier validTokens(address token0, address token1) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Same tokens");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Registra uma nova estratégia de pricing
     */
    function registerStrategy(
        string calldata name,
        address strategyContract,
        string calldata description
    ) external onlyOwner {
        require(bytes(name).length > 0, "Empty name");
        require(strategyContract != address(0), "Invalid contract");
        require(strategies[name].strategyContract == address(0), "Strategy already exists");
        
        PricingConfig memory config = PricingConfig({
            strategyName: name,
            strategyContract: strategyContract,
            isActive: true,
            weight: 100, // Default weight
            lastUpdateTime: block.timestamp,
            description: description
        });
        
        strategies[name] = config;
        strategyNames.push(name);
        authorizedStrategies[strategyContract] = true;
        strategyContracts[name] = strategyContract;
        
        totalStrategies++;
        
        emit StrategyRegistered(name, strategyContract, description);
    }
    
    /**
     * @dev Atualiza uma estratégia existente
     */
    function updateStrategy(
        string calldata name,
        address strategyContract,
        uint256 weight
    ) external onlyOwner {
        require(strategies[name].strategyContract != address(0), "Strategy not found");
        require(strategyContract != address(0), "Invalid contract");
        
        // Desautorizar estratégia antiga
        authorizedStrategies[strategies[name].strategyContract] = false;
        
        // Atualizar estratégia
        strategies[name].strategyContract = strategyContract;
        strategies[name].weight = weight;
        strategies[name].lastUpdateTime = block.timestamp;
        
        // Autorizar nova estratégia
        authorizedStrategies[strategyContract] = true;
        strategyContracts[name] = strategyContract;
        
        emit StrategyUpdated(name, strategyContract);
    }
    
    /**
     * @dev Desativa uma estratégia
     */
    function deactivateStrategy(string calldata name) external onlyOwner {
        require(strategies[name].strategyContract != address(0), "Strategy not found");
        
        strategies[name].isActive = false;
        authorizedStrategies[strategies[name].strategyContract] = false;
        
        emit StrategyDeactivated(name);
    }
    
    /**
     * @dev Atualiza preço de um par de tokens
     */
    function updatePrice(
        address token0,
        address token1,
        uint256 price,
        uint256 confidence,
        string calldata source
    ) external onlyAuthorizedStrategy validTokens(token0, token1) {
        require(price > 0, "Invalid price");
        require(confidence <= 100, "Invalid confidence");
        
        PriceData memory priceData = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence,
            source: source
        });
        
        priceFeeds[token0][token1] = priceData;
        
        emit PriceUpdated(token0, token1, price, source);
    }
    
    /**
     * @dev Executa swap usando estratégia específica
     */
    function executeSwap(SwapParams calldata params) external nonReentrant returns (uint256 amountOut) {
        require(strategies[params.strategy].isActive, "Strategy inactive");
        require(strategies[params.strategy].strategyContract != address(0), "Strategy not found");
        
        // Chamar estratégia específica
        bytes memory callData = abi.encodeWithSignature(
            "calculateSwap(address,address,uint256,uint256,address)",
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            params.minAmountOut,
            params.recipient
        );
        
        (bool success, bytes memory result) = strategies[params.strategy].strategyContract.delegatecall(callData);
        require(success, "Strategy execution failed");
        
        amountOut = abi.decode(result, (uint256));
        
        emit SwapExecuted(msg.sender, params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.strategy);
        
        return amountOut;
    }
    
    /**
     * @dev Calcula preço usando estratégia específica
     */
    function calculatePrice(
        address token0,
        address token1,
        string calldata strategy
    ) external view returns (uint256 price, uint256 confidence) {
        require(strategies[strategy].isActive, "Strategy inactive");
        
        bytes memory callData = abi.encodeWithSignature(
            "getPrice(address,address)",
            token0,
            token1
        );
        
        (bool success, bytes memory result) = strategies[strategy].strategyContract.staticcall(callData);
        require(success, "Price calculation failed");
        
        (price, confidence) = abi.decode(result, (uint256, uint256));
    }
    
    /**
     * @dev Calcula preço usando múltiplas estratégias (weighted average)
     */
    function calculateWeightedPrice(
        address token0,
        address token1
    ) external view returns (uint256 weightedPrice, uint256 totalConfidence) {
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        uint256 totalConf = 0;
        
        for (uint256 i = 0; i < strategyNames.length; i++) {
            string memory strategyName = strategyNames[i];
            PricingConfig memory config = strategies[strategyName];
            
            if (config.isActive) {
                try this.calculatePrice(token0, token1, strategyName) returns (uint256 price, uint256 confidence) {
                    uint256 weight = config.weight * confidence / 100;
                    weightedSum += price * weight;
                    totalWeight += weight;
                    totalConf += confidence;
                } catch {
                    // Estratégia falhou, continuar com as outras
                    continue;
                }
            }
        }
        
        if (totalWeight > 0) {
            weightedPrice = weightedSum / totalWeight;
            totalConfidence = totalConf / totalStrategies;
        }
    }
    
    /**
     * @dev Retorna melhor preço entre todas as estratégias
     */
    function getBestPrice(
        address token0,
        address token1
    ) external view returns (uint256 bestPrice, string memory bestStrategy) {
        uint256 highestConfidence = 0;
        
        for (uint256 i = 0; i < strategyNames.length; i++) {
            string memory strategyName = strategyNames[i];
            PricingConfig memory config = strategies[strategyName];
            
            if (config.isActive) {
                try this.calculatePrice(token0, token1, strategyName) returns (uint256 price, uint256 confidence) {
                    if (confidence > highestConfidence) {
                        highestConfidence = confidence;
                        bestPrice = price;
                        bestStrategy = strategyName;
                    }
                } catch {
                    continue;
                }
            }
        }
    }
    
    /**
     * @dev Retorna configuração de uma estratégia
     */
    function getStrategyConfig(string calldata name) external view returns (PricingConfig memory) {
        return strategies[name];
    }
    
    /**
     * @dev Retorna todas as estratégias ativas
     */
    function getActiveStrategies() external view returns (string[] memory activeStrategies) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < strategyNames.length; i++) {
            if (strategies[strategyNames[i]].isActive) {
                activeCount++;
            }
        }
        
        activeStrategies = new string[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < strategyNames.length; i++) {
            if (strategies[strategyNames[i]].isActive) {
                activeStrategies[index] = strategyNames[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Retorna dados de preço de um par
     */
    function getPriceData(
        address token0,
        address token1
    ) external view returns (PriceData memory) {
        return priceFeeds[token0][token1];
    }
    
    /**
     * @dev Retorna estatísticas das estratégias
     */
    function getStrategyStats() external view returns (
        uint256 _totalStrategies,
        uint256 _activeStrategies,
        uint256 _totalPriceFeeds
    ) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < strategyNames.length; i++) {
            if (strategies[strategyNames[i]].isActive) {
                activeCount++;
            }
        }
        
        return (totalStrategies, activeCount, strategyNames.length);
    }
}

/**
 * @title ConstantProductPricing
 * @dev Estratégia de pricing usando fórmula de produto constante (AMM)
 */
contract ConstantProductPricing {
    
    function calculateSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external pure returns (uint256 amountOut) {
        // Simulação de cálculo AMM (x * y = k)
        // Em produção, isso seria uma implementação real
        amountOut = amountIn * 99 / 100; // 1% fee
        require(amountOut >= minAmountOut, "Insufficient output");
        return amountOut;
    }
    
    function getPrice(address token0, address token1) external pure returns (uint256 price, uint256 confidence) {
        // Simulação de preço AMM
        price = 1000000; // 1:1 price (simplificado)
        confidence = 95; // 95% confidence
    }
}

/**
 * @title TWAPPricing
 * @dev Estratégia de pricing usando TWAP (Time-Weighted Average Price)
 */
contract TWAPPricing {
    
    function calculateSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external pure returns (uint256 amountOut) {
        // Simulação de cálculo TWAP
        amountOut = amountIn * 98 / 100; // 2% fee (maior para TWAP)
        require(amountOut >= minAmountOut, "Insufficient output");
        return amountOut;
    }
    
    function getPrice(address token0, address token1) external pure returns (uint256 price, uint256 confidence) {
        // Simulação de preço TWAP
        price = 1000000; // 1:1 price (simplificado)
        confidence = 90; // 90% confidence (menor que AMM)
    }
}

/**
 * @title OraclePricing
 * @dev Estratégia de pricing usando oracles externos
 */
contract OraclePricing {
    
    function calculateSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external pure returns (uint256 amountOut) {
        // Simulação de cálculo com oracle
        amountOut = amountIn * 97 / 100; // 3% fee (maior para oracle)
        require(amountOut >= minAmountOut, "Insufficient output");
        return amountOut;
    }
    
    function getPrice(address token0, address token1) external pure returns (uint256 price, uint256 confidence) {
        // Simulação de preço de oracle
        price = 1000000; // 1:1 price (simplificado)
        confidence = 85; // 85% confidence (menor que TWAP)
    }
} 