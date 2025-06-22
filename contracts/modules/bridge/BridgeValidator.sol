// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeValidator {
    address public owner;
    mapping(address => uint256) public stakes;
    mapping(address => bool) public validators;
    uint256 public minStake;
    uint256 public totalStaked;

    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorUnregistered(address indexed validator);
    event StakeAdded(address indexed validator, uint256 amount);
    event StakeRemoved(address indexed validator, uint256 amount);
    event ValidatorSlashed(address indexed validator, uint256 amount, string reason);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyValidator() { require(validators[msg.sender], "Not validator"); _; }

    constructor(uint256 _minStake) { owner = msg.sender; minStake = _minStake; }

    function registerValidator() external payable {
        require(msg.value >= minStake, "Insufficient stake");
        require(!validators[msg.sender], "Already validator");
        validators[msg.sender] = true;
        stakes[msg.sender] = msg.value;
        totalStaked += msg.value;
        emit ValidatorRegistered(msg.sender, msg.value);
    }

    function unregisterValidator() external onlyValidator {
        validators[msg.sender] = false;
        uint256 stake = stakes[msg.sender];
        stakes[msg.sender] = 0;
        totalStaked -= stake;
        payable(msg.sender).transfer(stake);
        emit ValidatorUnregistered(msg.sender);
    }

    function addStake() external payable onlyValidator {
        stakes[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit StakeAdded(msg.sender, msg.value);
    }

    function removeStake(uint256 amount) external onlyValidator {
        require(stakes[msg.sender] >= amount, "Insufficient stake");
        stakes[msg.sender] -= amount;
        totalStaked -= amount;
        payable(msg.sender).transfer(amount);
        emit StakeRemoved(msg.sender, amount);
    }

    function slashValidator(address validator, uint256 amount, string calldata reason) external onlyOwner {
        require(validators[validator], "Not validator");
        require(stakes[validator] >= amount, "Insufficient stake to slash");
        stakes[validator] -= amount;
        totalStaked -= amount;
        emit ValidatorSlashed(validator, amount, reason);
    }

    function getValidatorStake(address validator) external view returns (uint256) {
        return stakes[validator];
    }

    function isValidator(address validator) external view returns (bool) {
        return validators[validator];
    }
} 