// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/ILoraRouter.sol";

/**
 * @title RouteOptimizer
 * @dev Otimizador de rotas para multi-hop routing
 */
contract RouteOptimizer is ReentrancyGuard, Ownable {
    
    struct PoolInfo {
        address pool;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
        uint256 volume24h;
        bool isActive;
    }
    
    struct RouteInfo {
        address[] pools;
        address[] tokens;
        uint24[] fees;
        uint256[] amounts;
        uint256 gasEstimate;
        uint256 totalFee;
        uint256 slippage;
    }
    
    mapping(address => mapping(address => mapping(uint24 => PoolInfo))) public pools;
    mapping(address => address[]) public tokenPools;
    
    uint256 public constant MAX_HOPS = 5;
    uint256 public constant MAX_SPLIT_ROUTES = 3;
    uint256 public constant GAS_PER_HOP = 100000;
    
    event PoolAdded(address indexed token0, address indexed token1, uint24 fee, address pool);
    event PoolRemoved(address indexed token0, address indexed token1, uint24 fee, address pool);
    event RouteOptimized(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, RouteInfo route);
    
    modifier validTokens(address token0, address token1) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Same tokens");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Adiciona pool ao otimizador
     */
    function addPool(
        address token0,
        address token1,
        uint24 fee,
        address pool,
        uint128 liquidity,
        uint256 volume24h
    ) external onlyOwner validTokens(token0, token1) {
        require(pool != address(0), "Invalid pool");
        
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        
        pools[tokenA][tokenB][fee] = PoolInfo({
            pool: pool,
            token0: tokenA,
            token1: tokenB,
            fee: fee,
            liquidity: liquidity,
            volume24h: volume24h,
            isActive: true
        });
        
        // Adicionar à lista de pools do token
        _addTokenPool(tokenA, pool);
        _addTokenPool(tokenB, pool);
        
        emit PoolAdded(tokenA, tokenB, fee, pool);
    }
    
    /**
     * @dev Remove pool do otimizador
     */
    function removePool(address token0, address token1, uint24 fee) external onlyOwner {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        
        delete pools[tokenA][tokenB][fee];
        emit PoolRemoved(tokenA, tokenB, fee, address(0));
    }
    
    /**
     * @dev Encontra rota otimizada
     */
    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        ILoraRouter.RouterConfig calldata config
    ) external view returns (ILoraRouter.Route memory optimalRoute) {
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Invalid amount");
        
        RouteInfo[] memory routes = _findAllRoutes(tokenIn, tokenOut, amountIn, config.maxHops);
        optimalRoute = _selectBestRoute(routes, config);
        
        return optimalRoute;
    }
    
    /**
     * @dev Encontra rotas divididas para grandes volumes
     */
    function findSplitRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        ILoraRouter.RouterConfig calldata config
    ) external view returns (ILoraRouter.Route[] memory routes) {
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Invalid amount");
        require(config.useSplitRoutes, "Split routes disabled");
        
        routes = new ILoraRouter.Route[](MAX_SPLIT_ROUTES);
        uint256 splitAmount = amountIn / MAX_SPLIT_ROUTES;
        
        for (uint256 i = 0; i < MAX_SPLIT_ROUTES; i++) {
            uint256 currentAmount = i == MAX_SPLIT_ROUTES - 1 ? 
                amountIn - (splitAmount * i) : splitAmount;
            
            RouteInfo[] memory routeOptions = _findAllRoutes(tokenIn, tokenOut, currentAmount, config.maxHops);
            routes[i] = _selectBestRoute(routeOptions, config);
        }
        
        return routes;
    }
    
    /**
     * @dev Estima gas para rota
     */
    function estimateGasForRoute(ILoraRouter.Route calldata route) external pure returns (uint256 gasEstimate) {
        gasEstimate = route.pools.length * GAS_PER_HOP;
        return gasEstimate;
    }
    
    /**
     * @dev Encontra todas as rotas possíveis
     */
    function _findAllRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxHops
    ) internal view returns (RouteInfo[] memory routes) {
        routes = new RouteInfo[](1);
        
        RouteInfo memory route;
        route.pools = new address[](1);
        route.tokens = new address[](2);
        route.fees = new uint24[](1);
        route.amounts = new uint256[](2);
        
        // Encontrar pool direto
        address pool = _findDirectPool(tokenIn, tokenOut);
        if (pool != address(0)) {
            route.pools[0] = pool;
            route.tokens[0] = tokenIn;
            route.tokens[1] = tokenOut;
            route.fees[0] = 3000; // 0.3%
            route.amounts[0] = amountIn;
            route.amounts[1] = amountIn; // Simplificado
            route.gasEstimate = GAS_PER_HOP;
            route.totalFee = amountIn * 3000 / 1000000;
            route.slippage = 50; // 0.5%
        }
        
        routes[0] = route;
        return routes;
    }
    
    /**
     * @dev Seleciona melhor rota
     */
    function _selectBestRoute(
        RouteInfo[] memory routes,
        ILoraRouter.RouterConfig calldata config
    ) internal pure returns (ILoraRouter.Route memory bestRoute) {
        require(routes.length > 0, "No routes found");
        
        uint256 bestScore = type(uint256).max;
        
        for (uint256 i = 0; i < routes.length; i++) {
            if (routes[i].pools.length == 0) continue;
            
            uint256 score = _calculateRouteScore(routes[i], config);
            if (score < bestScore) {
                bestScore = score;
                bestRoute.pools = routes[i].pools;
                bestRoute.tokens = routes[i].tokens;
                bestRoute.fees = routes[i].fees;
                bestRoute.amounts = routes[i].amounts;
            }
        }
        
        return bestRoute;
    }
    
    /**
     * @dev Calcula score da rota
     */
    function _calculateRouteScore(
        RouteInfo memory route,
        ILoraRouter.RouterConfig calldata config
    ) internal pure returns (uint256 score) {
        score = route.gasEstimate * 1000 + route.totalFee * 100 + route.slippage;
        
        if (route.pools.length > config.maxHops) {
            score += (route.pools.length - config.maxHops) * 10000;
        }
        
        return score;
    }
    
    /**
     * @dev Encontra pool direto entre tokens
     */
    function _findDirectPool(address token0, address token1) internal view returns (address pool) {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        
        uint24[] memory fees = new uint24[](4);
        fees[0] = 100;   // 0.01%
        fees[1] = 500;   // 0.05%
        fees[2] = 3000;  // 0.3%
        fees[3] = 10000; // 1%
        
        for (uint256 i = 0; i < fees.length; i++) {
            PoolInfo memory poolInfo = pools[tokenA][tokenB][fees[i]];
            if (poolInfo.isActive && poolInfo.liquidity > 0) {
                return poolInfo.pool;
            }
        }
        
        return address(0);
    }
    
    /**
     * @dev Adiciona pool à lista de pools do token
     */
    function _addTokenPool(address token, address pool) internal {
        address[] storage tokenPoolList = tokenPools[token];
        
        for (uint256 i = 0; i < tokenPoolList.length; i++) {
            if (tokenPoolList[i] == pool) {
                return;
            }
        }
        
        tokenPoolList.push(pool);
    }
    
    /**
     * @dev Atualiza informações do pool
     */
    function updatePoolInfo(
        address token0,
        address token1,
        uint24 fee,
        uint128 liquidity,
        uint256 volume24h
    ) external onlyOwner {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        
        PoolInfo storage poolInfo = pools[tokenA][tokenB][fee];
        require(poolInfo.pool != address(0), "Pool not found");
        
        poolInfo.liquidity = liquidity;
        poolInfo.volume24h = volume24h;
    }
    
    /**
     * @dev Retorna pools de um token
     */
    function getTokenPools(address token) external view returns (address[] memory) {
        return tokenPools[token];
    }
    
    /**
     * @dev Retorna informações do pool
     */
    function getPoolInfo(
        address token0,
        address token1,
        uint24 fee
    ) external view returns (PoolInfo memory) {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        return pools[tokenA][tokenB][fee];
    }
} 