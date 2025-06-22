// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PoolRegistry
 * @dev Registry Pattern para discovery de pools e serviços
 */
contract PoolRegistry is ReentrancyGuard, Ownable {
    
    struct PoolInfo {
        address pool;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
        uint256 volume24h;
        uint256 tvl;
        bool isActive;
        uint256 lastUpdateTime;
        string poolType;
        address factory;
    }
    
    struct ServiceInfo {
        address service;
        string name;
        string version;
        bool isActive;
        uint256 registrationTime;
        address owner;
        string description;
        string[] tags;
    }
    
    struct TokenInfo {
        address token;
        string symbol;
        string name;
        uint8 decimals;
        bool isWhitelisted;
        uint256 totalPools;
        uint256 totalVolume;
        address[] pools;
    }
    
    mapping(bytes32 => PoolInfo) public pools;
    mapping(address => ServiceInfo) public services;
    mapping(address => TokenInfo) public tokens;
    mapping(string => address[]) public poolsByType;
    mapping(address => bytes32[]) public poolsByToken;
    mapping(address => address[]) public servicesByOwner;
    
    bytes32[] public poolIds;
    address[] public serviceAddresses;
    address[] public tokenAddresses;
    
    uint256 public totalPools;
    uint256 public totalServices;
    uint256 public totalTokens;
    
    event PoolRegistered(
        bytes32 indexed poolId,
        address indexed pool,
        address indexed factory,
        address token0,
        address token1,
        uint24 fee,
        string poolType
    );
    
    event PoolUpdated(
        bytes32 indexed poolId,
        uint128 liquidity,
        uint256 volume24h,
        uint256 tvl
    );
    
    event ServiceRegistered(
        address indexed service,
        address indexed owner,
        string name,
        string version
    );
    
    event TokenRegistered(
        address indexed token,
        string symbol,
        string name,
        uint8 decimals
    );
    
    event PoolDeactivated(bytes32 indexed poolId);
    event ServiceDeactivated(address indexed service);
    event TokenWhitelistUpdated(address indexed token, bool whitelisted);
    
    modifier onlyAuthorized() {
        require(msg.sender == owner() || services[msg.sender].isActive, "Not authorized");
        _;
    }
    
    modifier validPool(address pool) {
        require(pool != address(0), "Invalid pool address");
        _;
    }
    
    modifier validTokens(address token0, address token1) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Same tokens");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Registra um novo pool
     */
    function registerPool(
        address pool,
        address token0,
        address token1,
        uint24 fee,
        string calldata poolType,
        address factory
    ) external onlyAuthorized validPool(pool) validTokens(token0, token1) {
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1, fee, poolType));
        require(pools[poolId].pool == address(0), "Pool already registered");
        
        PoolInfo memory poolInfo = PoolInfo({
            pool: pool,
            token0: token0,
            token1: token1,
            fee: fee,
            liquidity: 0,
            volume24h: 0,
            tvl: 0,
            isActive: true,
            lastUpdateTime: block.timestamp,
            poolType: poolType,
            factory: factory
        });
        
        pools[poolId] = poolInfo;
        poolIds.push(poolId);
        poolsByType[poolType].push(pool);
        poolsByToken[token0].push(poolId);
        poolsByToken[token1].push(poolId);
        
        // Atualizar contadores de tokens
        _updateTokenPoolCount(token0, pool);
        _updateTokenPoolCount(token1, pool);
        
        totalPools++;
        
        emit PoolRegistered(poolId, pool, factory, token0, token1, fee, poolType);
    }
    
    /**
     * @dev Atualiza informações de um pool
     */
    function updatePool(
        bytes32 poolId,
        uint128 liquidity,
        uint256 volume24h,
        uint256 tvl
    ) external onlyAuthorized {
        require(pools[poolId].pool != address(0), "Pool not found");
        
        PoolInfo storage poolInfo = pools[poolId];
        poolInfo.liquidity = liquidity;
        poolInfo.volume24h = volume24h;
        poolInfo.tvl = tvl;
        poolInfo.lastUpdateTime = block.timestamp;
        
        emit PoolUpdated(poolId, liquidity, volume24h, tvl);
    }
    
    /**
     * @dev Registra um novo serviço
     */
    function registerService(
        string calldata name,
        string calldata version,
        string calldata description,
        string[] calldata tags
    ) external {
        require(bytes(name).length > 0, "Empty name");
        require(bytes(version).length > 0, "Empty version");
        require(services[msg.sender].service == address(0), "Service already registered");
        
        ServiceInfo memory serviceInfo = ServiceInfo({
            service: msg.sender,
            name: name,
            version: version,
            isActive: true,
            registrationTime: block.timestamp,
            owner: msg.sender,
            description: description,
            tags: tags
        });
        
        services[msg.sender] = serviceInfo;
        serviceAddresses.push(msg.sender);
        servicesByOwner[msg.sender].push(msg.sender);
        
        totalServices++;
        
        emit ServiceRegistered(msg.sender, msg.sender, name, version);
    }
    
    /**
     * @dev Registra um novo token
     */
    function registerToken(
        address token,
        string calldata symbol,
        string calldata name,
        uint8 decimals
    ) external onlyAuthorized {
        require(token != address(0), "Invalid token");
        require(bytes(symbol).length > 0, "Empty symbol");
        require(tokens[token].token == address(0), "Token already registered");
        
        TokenInfo memory tokenInfo = TokenInfo({
            token: token,
            symbol: symbol,
            name: name,
            decimals: decimals,
            isWhitelisted: true,
            totalPools: 0,
            totalVolume: 0,
            pools: new address[](0)
        });
        
        tokens[token] = tokenInfo;
        tokenAddresses.push(token);
        
        totalTokens++;
        
        emit TokenRegistered(token, symbol, name, decimals);
    }
    
    /**
     * @dev Desativa um pool
     */
    function deactivatePool(bytes32 poolId) external onlyAuthorized {
        require(pools[poolId].pool != address(0), "Pool not found");
        
        pools[poolId].isActive = false;
        
        emit PoolDeactivated(poolId);
    }
    
    /**
     * @dev Desativa um serviço
     */
    function deactivateService(address service) external onlyAuthorized {
        require(services[service].service != address(0), "Service not found");
        
        services[service].isActive = false;
        
        emit ServiceDeactivated(service);
    }
    
    /**
     * @dev Atualiza whitelist de token
     */
    function updateTokenWhitelist(address token, bool whitelisted) external onlyAuthorized {
        require(tokens[token].token != address(0), "Token not found");
        
        tokens[token].isWhitelisted = whitelisted;
        
        emit TokenWhitelistUpdated(token, whitelisted);
    }
    
    /**
     * @dev Busca pools por tokens
     */
    function findPoolsByTokens(
        address token0,
        address token1
    ) external view returns (PoolInfo[] memory foundPools) {
        bytes32[] memory token0Pools = poolsByToken[token0];
        bytes32[] memory token1Pools = poolsByToken[token1];
        
        // Encontrar pools que contêm ambos os tokens
        uint256 matchCount = 0;
        for (uint256 i = 0; i < token0Pools.length; i++) {
            for (uint256 j = 0; j < token1Pools.length; j++) {
                if (token0Pools[i] == token1Pools[j] && pools[token0Pools[i]].isActive) {
                    matchCount++;
                }
            }
        }
        
        foundPools = new PoolInfo[](matchCount);
        uint256 index = 0;
        for (uint256 i = 0; i < token0Pools.length; i++) {
            for (uint256 j = 0; j < token1Pools.length; j++) {
                if (token0Pools[i] == token1Pools[j] && pools[token0Pools[i]].isActive) {
                    foundPools[index] = pools[token0Pools[i]];
                    index++;
                }
            }
        }
    }
    
    /**
     * @dev Busca pools por tipo
     */
    function findPoolsByType(string calldata poolType) external view returns (PoolInfo[] memory foundPools) {
        address[] memory poolAddresses = poolsByType[poolType];
        foundPools = new PoolInfo[](poolAddresses.length);
        
        for (uint256 i = 0; i < poolAddresses.length; i++) {
            // Encontrar poolId correspondente
            for (uint256 j = 0; j < poolIds.length; j++) {
                if (pools[poolIds[j]].pool == poolAddresses[i] && pools[poolIds[j]].isActive) {
                    foundPools[i] = pools[poolIds[j]];
                    break;
                }
            }
        }
    }
    
    /**
     * @dev Busca serviços por tag
     */
    function findServicesByTag(string calldata tag) external view returns (ServiceInfo[] memory foundServices) {
        uint256 matchCount = 0;
        for (uint256 i = 0; i < serviceAddresses.length; i++) {
            ServiceInfo memory service = services[serviceAddresses[i]];
            if (service.isActive) {
                for (uint256 j = 0; j < service.tags.length; j++) {
                    if (keccak256(bytes(service.tags[j])) == keccak256(bytes(tag))) {
                        matchCount++;
                        break;
                    }
                }
            }
        }
        
        foundServices = new ServiceInfo[](matchCount);
        uint256 index = 0;
        for (uint256 i = 0; i < serviceAddresses.length; i++) {
            ServiceInfo memory service = services[serviceAddresses[i]];
            if (service.isActive) {
                for (uint256 j = 0; j < service.tags.length; j++) {
                    if (keccak256(bytes(service.tags[j])) == keccak256(bytes(tag))) {
                        foundServices[index] = service;
                        index++;
                        break;
                    }
                }
            }
        }
    }
    
    /**
     * @dev Retorna estatísticas do registry
     */
    function getRegistryStats() external view returns (
        uint256 _totalPools,
        uint256 _totalServices,
        uint256 _totalTokens,
        uint256 _activePools,
        uint256 _activeServices,
        uint256 _whitelistedTokens
    ) {
        uint256 activePools = 0;
        uint256 activeServices = 0;
        uint256 whitelistedTokens = 0;
        
        for (uint256 i = 0; i < poolIds.length; i++) {
            if (pools[poolIds[i]].isActive) {
                activePools++;
            }
        }
        
        for (uint256 i = 0; i < serviceAddresses.length; i++) {
            if (services[serviceAddresses[i]].isActive) {
                activeServices++;
            }
        }
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (tokens[tokenAddresses[i]].isWhitelisted) {
                whitelistedTokens++;
            }
        }
        
        return (totalPools, totalServices, totalTokens, activePools, activeServices, whitelistedTokens);
    }
    
    /**
     * @dev Atualiza contador de pools de um token
     */
    function _updateTokenPoolCount(address token, address pool) internal {
        if (tokens[token].token != address(0)) {
            tokens[token].totalPools++;
            tokens[token].pools.push(pool);
        }
    }
    
    /**
     * @dev Retorna todos os pools
     */
    function getAllPools() external view returns (PoolInfo[] memory) {
        PoolInfo[] memory allPools = new PoolInfo[](poolIds.length);
        for (uint256 i = 0; i < poolIds.length; i++) {
            allPools[i] = pools[poolIds[i]];
        }
        return allPools;
    }
    
    /**
     * @dev Retorna todos os serviços
     */
    function getAllServices() external view returns (ServiceInfo[] memory) {
        ServiceInfo[] memory allServices = new ServiceInfo[](serviceAddresses.length);
        for (uint256 i = 0; i < serviceAddresses.length; i++) {
            allServices[i] = services[serviceAddresses[i]];
        }
        return allServices;
    }
    
    /**
     * @dev Retorna todos os tokens
     */
    function getAllTokens() external view returns (TokenInfo[] memory) {
        TokenInfo[] memory allTokens = new TokenInfo[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            allTokens[i] = tokens[tokenAddresses[i]];
        }
        return allTokens;
    }
} 