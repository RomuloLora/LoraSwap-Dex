// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LoraToken
 * @dev Token ERC-20 para o ecossistema LoraSwap
 */
contract LoraToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ReentrancyGuard {
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 milhão de tokens
    uint256 public constant MAX_SUPPLY = 10000000 * 10**18; // 10 milhões de tokens máximo
    
    mapping(address => bool) public isMinter;
    mapping(address => uint256) public lastTransferTime;
    uint256 public transferCooldown = 1 hours;
    
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event TransferCooldownUpdated(uint256 newCooldown);
    
    constructor() ERC20("Lora Token", "LORA") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    /**
     * @dev Adiciona um minter
     */
    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid minter address");
        isMinter[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev Remove um minter
     */
    function removeMinter(address minter) external onlyOwner {
        require(isMinter[minter], "Not a minter");
        isMinter[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev Mint de novos tokens (apenas minters)
     */
    function mint(address to, uint256 amount) external nonReentrant {
        require(isMinter[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Atualiza o cooldown de transferência
     */
    function setTransferCooldown(uint256 newCooldown) external onlyOwner {
        transferCooldown = newCooldown;
        emit TransferCooldownUpdated(newCooldown);
    }
    
    /**
     * @dev Pausa o contrato
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Despausa o contrato
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Override da função transfer com cooldown
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(block.timestamp >= lastTransferTime[msg.sender] + transferCooldown, "Transfer cooldown active");
        lastTransferTime[msg.sender] = block.timestamp;
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override da função transferFrom
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Override das funções do ERC20Pausable
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
} 