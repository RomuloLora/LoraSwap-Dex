// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LoraDEX.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LoraFactory
 * @dev Factory para criar e gerenciar pares de trading
 */
contract LoraFactory is Ownable, ReentrancyGuard {
    // Variáveis de estado
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    // Eventos
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);
    event FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo);
    event FeeToSetterUpdated(address indexed oldFeeToSetter, address indexed newFeeToSetter);
    
    // Configurações
    address public feeTo;
    address public feeToSetter;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    
    constructor(address _feeToSetter) Ownable(msg.sender) {
        feeToSetter = _feeToSetter;
    }
    
    /**
     * @dev Retorna o número total de pares
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
    
    /**
     * @dev Cria um novo par de trading
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "LoraFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "LoraFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "LoraFactory: PAIR_EXISTS");
        
        // Deploy do novo par
        bytes memory bytecode = type(LoraDEX).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        LoraDEX(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    /**
     * @dev Define o endereço que recebe as taxas
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "LoraFactory: FORBIDDEN");
        address oldFeeTo = feeTo;
        feeTo = _feeTo;
        emit FeeToUpdated(oldFeeTo, _feeTo);
    }
    
    /**
     * @dev Define quem pode alterar o feeTo
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "LoraFactory: FORBIDDEN");
        address oldFeeToSetter = feeToSetter;
        feeToSetter = _feeToSetter;
        emit FeeToSetterUpdated(oldFeeToSetter, _feeToSetter);
    }
    
    /**
     * @dev Retorna todos os pares
     */
    function getAllPairs() external view returns (address[] memory) {
        return allPairs;
    }
    
    /**
     * @dev Verifica se um par existe
     */
    function pairExists(address tokenA, address tokenB) external view returns (bool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return getPair[token0][token1] != address(0);
    }
} 