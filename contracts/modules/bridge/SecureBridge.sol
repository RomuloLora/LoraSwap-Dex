// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecureBridge {
    address public owner;
    address[] public validators;
    mapping(address => bool) public isValidator;
    uint256 public minSignatures;
    uint256 public timeLockSeconds;
    bool public paused;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public slashed;

    event ValidatorSet(address indexed validator, bool enabled);
    event MinSignaturesSet(uint256 minSignatures);
    event TimeLockSet(uint256 seconds);
    event Paused(bool paused);
    event MessageProposed(bytes32 indexed msgHash, address indexed proposer, uint256 unlockTime);
    event MessageExecuted(bytes32 indexed msgHash);
    event ValidatorSlashed(address indexed validator, uint256 amount, string reason);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyValidator() { require(isValidator[msg.sender], "Not validator"); _; }
    modifier notPaused() { require(!paused, "Paused"); _; }

    struct Message {
        bytes data;
        uint256 unlockTime;
        address[] signatures;
        bool executed;
    }
    mapping(bytes32 => Message) public messages;

    constructor(address[] memory _validators, uint256 _minSignatures, uint256 _timeLockSeconds) {
        owner = msg.sender;
        for (uint256 i = 0; i < _validators.length; i++) {
            validators.push(_validators[i]);
            isValidator[_validators[i]] = true;
        }
        minSignatures = _minSignatures;
        timeLockSeconds = _timeLockSeconds;
    }

    function setValidator(address validator, bool enabled) external onlyOwner {
        isValidator[validator] = enabled;
        if (enabled) validators.push(validator);
        emit ValidatorSet(validator, enabled);
    }

    function setMinSignatures(uint256 n) external onlyOwner {
        minSignatures = n;
        emit MinSignaturesSet(n);
    }

    function setTimeLock(uint256 seconds_) external onlyOwner {
        timeLockSeconds = seconds_;
        emit TimeLockSet(seconds_);
    }

    function pause(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    // Propor mensagem cross-chain (precisa de time-lock e multi-sig)
    function proposeMessage(bytes calldata data) external onlyValidator notPaused {
        bytes32 msgHash = keccak256(data);
        require(!messages[msgHash].executed, "Already executed");
        Message storage m = messages[msgHash];
        if (m.unlockTime == 0) {
            m.data = data;
            m.unlockTime = block.timestamp + timeLockSeconds;
            m.signatures.push(msg.sender);
            emit MessageProposed(msgHash, msg.sender, m.unlockTime);
        } else {
            // Prevent duplicate signatures
            for (uint256 i = 0; i < m.signatures.length; i++) {
                require(m.signatures[i] != msg.sender, "Already signed");
            }
            m.signatures.push(msg.sender);
        }
    }

    // Executar mensagem após time-lock e multi-sig
    function executeMessage(bytes calldata data) external notPaused {
        bytes32 msgHash = keccak256(data);
        Message storage m = messages[msgHash];
        require(!m.executed, "Already executed");
        require(m.unlockTime > 0 && block.timestamp >= m.unlockTime, "Time-lock");
        require(m.signatures.length >= minSignatures, "Not enough signatures");
        m.executed = true;
        processedMessages[msgHash] = true;
        emit MessageExecuted(msgHash);
        // Aqui, lógica de execução cross-chain (ex: call destino)
    }

    // Slashing: penalizar validator por má conduta
    function slashValidator(address validator, uint256 amount, string calldata reason) external onlyOwner {
        require(isValidator[validator], "Not validator");
        slashed[validator] += amount;
        emit ValidatorSlashed(validator, amount, reason);
    }

    // Verificação de mensagem cross-chain (proof-of-execution)
    function verifyMessage(bytes calldata data, address[] calldata sigs) external view returns (bool) {
        bytes32 msgHash = keccak256(data);
        Message storage m = messages[msgHash];
        if (m.executed && m.signatures.length >= minSignatures) {
            // Verifica se todos os signatários são validators
            for (uint256 i = 0; i < sigs.length; i++) {
                if (!isValidator[sigs[i]]) return false;
            }
            return true;
        }
        return false;
    }
} 