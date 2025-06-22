// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../concentrated/ConcentratedPool.sol";
import "../../interfaces/ILoraDEX.sol";

/**
 * @title PoolFactory
 * @dev Factory Pattern para criação dinâmica de pools
 */
contract PoolFactory is ReentrancyGuard, Ownable {
    
    struct PoolTemplate {
        string name;
        address implementation;
        uint24[] supportedFees;
        bool isActive;
        uint256 creationCount;
    }
    
    struct PoolConfig {
        address token0;
        address token1;
        uint24 fee;
        uint160 initialSqrtPriceX96;
        int24 initialTick;
        string poolName;
    }
    
    mapping(bytes32 => address) public pools;
    mapping(string => PoolTemplate) public poolTemplates;
    mapping(address => bytes32[]) public poolsByToken;
    mapping(address => bool) public authorizedCreators;
    
    string[] public templateNames;
    uint256 public totalPools;
    
    event PoolCreated(
        bytes32 indexed poolId,
        address indexed pool,
        address indexed creator,
        address token0,
        address token1,
        uint24 fee,
        string template
    );
    
    event TemplateAdded(string indexed name, address implementation);
    event TemplateUpdated(string indexed name, address implementation);
    event CreatorAuthorized(address indexed creator, bool authorized);
    
    modifier onlyAuthorized() {
        require(authorizedCreators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    modifier validTokens(address token0, address token1) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Same tokens");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Autorizar o owner como criador
        authorizedCreators[msg.sender] = true;
    }
    
    /**
     * @dev Adiciona template de pool
     */
    function addPoolTemplate(
        string calldata name,
        address implementation,
        uint24[] calldata supportedFees
    ) external onlyOwner {
        require(bytes(name).length > 0, "Empty name");
        require(implementation != address(0), "Invalid implementation");
        require(supportedFees.length > 0, "No fees provided");
        
        poolTemplates[name] = PoolTemplate({
            name: name,
            implementation: implementation,
            supportedFees: supportedFees,
            isActive: true,
            creationCount: 0
        });
        
        templateNames.push(name);
        
        emit TemplateAdded(name, implementation);
    }
    
    /**
     * @dev Atualiza template de pool
     */
    function updatePoolTemplate(
        string calldata name,
        address implementation,
        uint24[] calldata supportedFees
    ) external onlyOwner {
        require(poolTemplates[name].implementation != address(0), "Template not found");
        require(implementation != address(0), "Invalid implementation");
        
        poolTemplates[name].implementation = implementation;
        poolTemplates[name].supportedFees = supportedFees;
        
        emit TemplateUpdated(name, implementation);
    }
    
    /**
     * @dev Cria novo pool usando template
     */
    function createPool(
        PoolConfig calldata config,
        string calldata templateName
    ) external onlyAuthorized validTokens(config.token0, config.token1) returns (address pool) {
        return _createPoolInternal(config, templateName);
    }
    
    /**
     * @dev Cria pool com configuração padrão
     */
    function createStandardPool(
        address token0,
        address token1,
        uint24 fee
    ) external onlyAuthorized validTokens(token0, token1) returns (address pool) {
        PoolConfig memory config = PoolConfig({
            token0: token0,
            token1: token1,
            fee: fee,
            initialSqrtPriceX96: 79228162514264337593543950336, // 1:1 price
            initialTick: 0,
            poolName: "Standard Pool"
        });
        
        return _createPoolInternal(config, "standard");
    }
    
    /**
     * @dev Cria pool com liquidez concentrada
     */
    function createConcentratedPool(
        address token0,
        address token1,
        uint24 fee
    ) external onlyAuthorized validTokens(token0, token1) returns (address pool) {
        PoolConfig memory config = PoolConfig({
            token0: token0,
            token1: token1,
            fee: fee,
            initialSqrtPriceX96: 79228162514264337593543950336,
            initialTick: 0,
            poolName: "Concentrated Pool"
        });
        
        return _createPoolInternal(config, "concentrated");
    }
    
    /**
     * @dev Autoriza/desautoriza criador de pools
     */
    function setCreatorAuthorization(address creator, bool authorized) external onlyOwner {
        authorizedCreators[creator] = authorized;
        emit CreatorAuthorized(creator, authorized);
    }
    
    /**
     * @dev Deploy do pool usando template
     */
    function _deployPool(PoolConfig memory config, address implementation) internal returns (address pool) {
        // Deploy usando create2 para endereços determinísticos
        bytes32 salt = keccak256(abi.encodePacked(
            config.token0,
            config.token1,
            config.fee,
            block.timestamp
        ));
        
        bytes memory bytecode = abi.encodePacked(
            type(ConcentratedPool).creationCode,
            abi.encode(config.token0, config.token1, config.fee)
        );
        
        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(pool != address(0), "Deploy failed");
    }
    
    /**
     * @dev Função interna para criar pool
     */
    function _createPoolInternal(
        PoolConfig memory config,
        string memory templateName
    ) internal returns (address pool) {
        PoolTemplate storage template = poolTemplates[templateName];
        require(template.isActive, "Template inactive");
        require(template.implementation != address(0), "Template not found");
        
        // Verificar se fee é suportado
        bool feeSupported = false;
        for (uint256 i = 0; i < template.supportedFees.length; i++) {
            if (template.supportedFees[i] == config.fee) {
                feeSupported = true;
                break;
            }
        }
        require(feeSupported, "Fee not supported");
        
        // Gerar pool ID único
        bytes32 poolId = keccak256(abi.encodePacked(
            config.token0,
            config.token1,
            config.fee,
            templateName,
            block.timestamp
        ));
        
        require(pools[poolId] == address(0), "Pool already exists");
        
        // Deploy do pool usando template
        pool = _deployPool(config, template.implementation);
        
        // Registrar pool
        pools[poolId] = pool;
        poolsByToken[config.token0].push(poolId);
        poolsByToken[config.token1].push(poolId);
        
        template.creationCount++;
        totalPools++;
        
        emit PoolCreated(poolId, pool, msg.sender, config.token0, config.token1, config.fee, templateName);
        
        return pool;
    }
    
    /**
     * @dev Retorna pool por ID
     */
    function getPool(bytes32 poolId) external view returns (address) {
        return pools[poolId];
    }
    
    /**
     * @dev Retorna pools por token
     */
    function getPoolsByToken(address token) external view returns (bytes32[] memory) {
        return poolsByToken[token];
    }
    
    /**
     * @dev Retorna template por nome
     */
    function getPoolTemplate(string calldata name) external view returns (PoolTemplate memory) {
        return poolTemplates[name];
    }
    
    /**
     * @dev Retorna todos os nomes de templates
     */
    function getTemplateNames() external view returns (string[] memory) {
        return templateNames;
    }
    
    /**
     * @dev Verifica se pool existe
     */
    function poolExists(bytes32 poolId) external view returns (bool) {
        return pools[poolId] != address(0);
    }
    
    /**
     * @dev Retorna estatísticas da factory
     */
    function getFactoryStats() external view returns (
        uint256 _totalPools,
        uint256 _templateCount,
        uint256 _authorizedCreators
    ) {
        uint256 creatorCount = 0;
        // Em produção, seria necessário iterar sobre todos os criadores
        // Por simplicidade, retornamos apenas o total de pools e templates
        return (totalPools, templateNames.length, creatorCount);
    }
} 