// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Commit Reveal Scheme
 * @dev Sistema commit-reveal para proteção contra front-running
 */
contract CommitReveal is ReentrancyGuard, Ownable {
    
    struct Commit {
        bytes32 commitHash;
        uint256 timestamp;
        bool isRevealed;
        bool isValid;
    }
    
    struct SwapCommit {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 nonce;
        bytes32 commitHash;
        uint256 commitTimestamp;
        bool isRevealed;
        bool isExecuted;
    }
    
    // Configurações
    uint256 public constant COMMIT_DELAY = 60;      // 1 minuto de delay
    uint256 public constant REVEAL_WINDOW = 300;    // 5 minutos para revelar
    uint256 public constant MAX_COMMITS_PER_USER = 10;
    
    // Estado do contrato
    mapping(address => Commit[]) public userCommits;
    mapping(bytes32 => SwapCommit) public swapCommits;
    mapping(address => uint256) public userCommitCount;
    
    // Eventos
    event CommitSubmitted(address indexed user, bytes32 indexed commitHash, uint256 timestamp);
    event CommitRevealed(address indexed user, bytes32 indexed commitHash, address tokenIn, address tokenOut, uint256 amountIn);
    event SwapExecuted(address indexed user, bytes32 indexed commitHash, uint256 amountOut);
    event CommitExpired(address indexed user, bytes32 indexed commitHash);
    
    // Modificadores
    modifier validCommit(bytes32 commitHash) {
        require(swapCommits[commitHash].user != address(0), "Invalid commit");
        _;
    }
    
    modifier notRevealed(bytes32 commitHash) {
        require(!swapCommits[commitHash].isRevealed, "Already revealed");
        _;
    }
    
    modifier notExecuted(bytes32 commitHash) {
        require(!swapCommits[commitHash].isExecuted, "Already executed");
        _;
    }
    
    modifier withinRevealWindow(bytes32 commitHash) {
        require(
            block.timestamp <= swapCommits[commitHash].commitTimestamp + REVEAL_WINDOW,
            "Reveal window expired"
        );
        _;
    }
    
    modifier afterCommitDelay(bytes32 commitHash) {
        require(
            block.timestamp >= swapCommits[commitHash].commitTimestamp + COMMIT_DELAY,
            "Commit delay not met"
        );
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Submete um commit (hash da ordem de swap)
     * @param commitHash Hash da ordem (keccak256(abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, nonce, secret)))
     */
    function submitCommit(bytes32 commitHash) external nonReentrant {
        require(commitHash != bytes32(0), "Invalid commit hash");
        require(userCommitCount[msg.sender] < MAX_COMMITS_PER_USER, "Too many commits");
        
        // Verificar se o commit já existe
        require(swapCommits[commitHash].user == address(0), "Commit already exists");
        
        // Criar commit
        Commit memory newCommit = Commit({
            commitHash: commitHash,
            timestamp: block.timestamp,
            isRevealed: false,
            isValid: true
        });
        
        // Adicionar ao array do usuário
        userCommits[msg.sender].push(newCommit);
        userCommitCount[msg.sender]++;
        
        // Criar swap commit placeholder
        swapCommits[commitHash] = SwapCommit({
            user: msg.sender,
            tokenIn: address(0),
            tokenOut: address(0),
            amountIn: 0,
            minAmountOut: 0,
            nonce: 0,
            commitHash: commitHash,
            commitTimestamp: block.timestamp,
            isRevealed: false,
            isExecuted: false
        });
        
        emit CommitSubmitted(msg.sender, commitHash, block.timestamp);
    }
    
    /**
     * @dev Revela uma ordem de swap
     * @param tokenIn Token de entrada
     * @param tokenOut Token de saída
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída
     * @param nonce Nonce único
     * @param secret Secret usado para gerar o commit
     */
    function revealCommit(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 nonce,
        bytes32 secret
    ) external nonReentrant {
        // Reconstruir o commit hash
        bytes32 commitHash = keccak256(abi.encodePacked(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            nonce,
            secret
        ));
        
        require(swapCommits[commitHash].user == msg.sender, "Invalid commit");
        require(!swapCommits[commitHash].isRevealed, "Already revealed");
        require(
            block.timestamp <= swapCommits[commitHash].commitTimestamp + REVEAL_WINDOW,
            "Reveal window expired"
        );
        
        // Atualizar swap commit
        swapCommits[commitHash].tokenIn = tokenIn;
        swapCommits[commitHash].tokenOut = tokenOut;
        swapCommits[commitHash].amountIn = amountIn;
        swapCommits[commitHash].minAmountOut = minAmountOut;
        swapCommits[commitHash].nonce = nonce;
        swapCommits[commitHash].isRevealed = true;
        
        // Marcar commit como revelado
        _markCommitRevealed(msg.sender, commitHash);
        
        emit CommitRevealed(msg.sender, commitHash, tokenIn, tokenOut, amountIn);
    }
    
    /**
     * @dev Executa um swap após o commit ser revelado
     * @param commitHash Hash do commit
     */
    function executeSwap(bytes32 commitHash) 
        external 
        nonReentrant 
        validCommit(commitHash)
        notExecuted(commitHash)
        afterCommitDelay(commitHash)
    {
        SwapCommit storage swapCommit = swapCommits[commitHash];
        
        require(swapCommit.isRevealed, "Commit not revealed");
        require(
            block.timestamp <= swapCommit.commitTimestamp + REVEAL_WINDOW,
            "Reveal window expired"
        );
        
        // Marcar como executado
        swapCommit.isExecuted = true;
        
        // Aqui você integraria com o DEX principal
        // Por exemplo:
        // ILoraDEX dex = ILoraDEX(dexAddress);
        // uint256 amountOut = dex.swap(swapCommit.tokenIn, swapCommit.amountIn, swapCommit.minAmountOut);
        
        // Por enquanto, apenas emitimos um evento
        emit SwapExecuted(swapCommit.user, commitHash, 0); // amountOut seria calculado
    }
    
    /**
     * @dev Limpa commits expirados
     * @param user Endereço do usuário
     */
    function cleanExpiredCommits(address user) external {
        Commit[] storage commits = userCommits[user];
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = 0; i < commits.length; i++) {
            if (!commits[i].isRevealed && 
                currentTime > commits[i].timestamp + REVEAL_WINDOW) {
                
                // Marcar como expirado
                commits[i].isValid = false;
                
                // Limpar swap commit
                delete swapCommits[commits[i].commitHash];
                
                emit CommitExpired(user, commits[i].commitHash);
            }
        }
    }
    
    /**
     * @dev Marca um commit como revelado
     * @param user Endereço do usuário
     * @param commitHash Hash do commit
     */
    function _markCommitRevealed(address user, bytes32 commitHash) internal {
        Commit[] storage commits = userCommits[user];
        
        for (uint256 i = 0; i < commits.length; i++) {
            if (commits[i].commitHash == commitHash) {
                commits[i].isRevealed = true;
                break;
            }
        }
    }
    
    /**
     * @dev Retorna commits de um usuário
     * @param user Endereço do usuário
     * @return commits Array de commits
     */
    function getUserCommits(address user) external view returns (Commit[] memory commits) {
        return userCommits[user];
    }
    
    /**
     * @dev Retorna informações de um swap commit
     * @param commitHash Hash do commit
     * @return user Endereço do usuário
     * @return tokenIn Token de entrada
     * @return tokenOut Token de saída
     * @return amountIn Quantidade de entrada
     * @return minAmountOut Quantidade mínima de saída
     * @return isRevealed Se foi revelado
     * @return isExecuted Se foi executado
     */
    function getSwapCommit(bytes32 commitHash) 
        external 
        view 
        validCommit(commitHash)
        returns (
            address user,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            uint256 minAmountOut,
            bool isRevealed,
            bool isExecuted
        )
    {
        SwapCommit storage swapCommit = swapCommits[commitHash];
        return (
            swapCommit.user,
            swapCommit.tokenIn,
            swapCommit.tokenOut,
            swapCommit.amountIn,
            swapCommit.minAmountOut,
            swapCommit.isRevealed,
            swapCommit.isExecuted
        );
    }
    
    /**
     * @dev Verifica se um commit pode ser executado
     * @param commitHash Hash do commit
     * @return canExecute Verdadeiro se pode ser executado
     * @return reason Razão se não pode ser executado
     */
    function canExecuteCommit(bytes32 commitHash) 
        external 
        view 
        returns (bool canExecute, string memory reason)
    {
        if (swapCommits[commitHash].user == address(0)) {
            return (false, "Invalid commit");
        }
        
        SwapCommit storage swapCommit = swapCommits[commitHash];
        
        if (!swapCommit.isRevealed) {
            return (false, "Commit not revealed");
        }
        
        if (swapCommit.isExecuted) {
            return (false, "Already executed");
        }
        
        if (block.timestamp < swapCommit.commitTimestamp + COMMIT_DELAY) {
            return (false, "Commit delay not met");
        }
        
        if (block.timestamp > swapCommit.commitTimestamp + REVEAL_WINDOW) {
            return (false, "Reveal window expired");
        }
        
        return (true, "");
    }
    
    /**
     * @dev Retorna estatísticas de commits
     * @param user Endereço do usuário
     * @return totalCommits Total de commits
     * @return revealedCommits Commits revelados
     * @return executedCommits Commits executados
     * @return expiredCommits Commits expirados
     */
    function getCommitStats(address user) 
        external 
        view 
        returns (
            uint256 totalCommits,
            uint256 revealedCommits,
            uint256 executedCommits,
            uint256 expiredCommits
        )
    {
        Commit[] storage commits = userCommits[user];
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = 0; i < commits.length; i++) {
            if (commits[i].isValid) {
                totalCommits++;
                
                if (commits[i].isRevealed) {
                    revealedCommits++;
                    
                    // Verificar se foi executado
                    if (swapCommits[commits[i].commitHash].isExecuted) {
                        executedCommits++;
                    }
                } else if (currentTime > commits[i].timestamp + REVEAL_WINDOW) {
                    expiredCommits++;
                }
            }
        }
        
        return (totalCommits, revealedCommits, executedCommits, expiredCommits);
    }
    
    /**
     * @dev Atualiza configurações do contrato
     * @param _commitDelay Novo delay do commit
     * @param _revealWindow Nova janela de revelação
     * @param _maxCommitsPerUser Novo máximo de commits por usuário
     */
    function updateConfig(
        uint256 _commitDelay,
        uint256 _revealWindow,
        uint256 _maxCommitsPerUser
    ) external onlyOwner {
        require(_commitDelay > 0, "Invalid commit delay");
        require(_revealWindow > _commitDelay, "Invalid reveal window");
        require(_maxCommitsPerUser > 0 && _maxCommitsPerUser <= 100, "Invalid max commits");
        
        // Atualizar constantes (em uma implementação real, você usaria variáveis de estado)
        // COMMIT_DELAY = _commitDelay;
        // REVEAL_WINDOW = _revealWindow;
        // MAX_COMMITS_PER_USER = _maxCommitsPerUser;
    }
} 