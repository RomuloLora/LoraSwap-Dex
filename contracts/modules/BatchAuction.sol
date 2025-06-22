// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Batch Auction
 * @dev Sistema de leilões em lote para proteção contra MEV
 */
contract BatchAuction is ReentrancyGuard, Ownable {
    
    struct Auction {
        uint256 auctionId;
        uint256 startTime;
        uint256 endTime;
        uint256 minBidAmount;
        uint256 totalBids;
        bool isActive;
        bool isSettled;
        mapping(address => uint256) bids;
        mapping(address => bool) hasBid;
    }
    
    struct SwapOrder {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 maxGasPrice;
        bytes swapData;
    }
    
    // Configurações
    uint256 public constant AUCTION_DURATION = 300; // 5 minutos
    uint256 public constant MIN_AUCTION_SIZE = 10;  // Mínimo de ordens por leilão
    uint256 public constant MAX_AUCTION_SIZE = 100; // Máximo de ordens por leilão
    
    // Estado do contrato
    uint256 public currentAuctionId;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => SwapOrder[]) public auctionOrders;
    
    // Eventos
    event AuctionCreated(uint256 indexed auctionId, uint256 startTime, uint256 endTime);
    event OrderSubmitted(uint256 indexed auctionId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn);
    event AuctionSettled(uint256 indexed auctionId, uint256 totalOrders, uint256 totalVolume);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    
    // Modificadores
    modifier auctionExists(uint256 auctionId) {
        require(auctionId <= currentAuctionId, "Auction does not exist");
        _;
    }
    
    modifier auctionActive(uint256 auctionId) {
        require(auctions[auctionId].isActive, "Auction not active");
        _;
    }
    
    modifier auctionNotSettled(uint256 auctionId) {
        require(!auctions[auctionId].isSettled, "Auction already settled");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Cria um novo leilão
     * @return auctionId ID do leilão criado
     */
    function createAuction() external onlyOwner returns (uint256 auctionId) {
        currentAuctionId++;
        auctionId = currentAuctionId;
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + AUCTION_DURATION;
        
        // Inicializar struct sem mapping
        auctions[auctionId].auctionId = auctionId;
        auctions[auctionId].startTime = startTime;
        auctions[auctionId].endTime = endTime;
        auctions[auctionId].minBidAmount = 0;
        auctions[auctionId].totalBids = 0;
        auctions[auctionId].isActive = true;
        auctions[auctionId].isSettled = false;
        
        emit AuctionCreated(auctionId, startTime, endTime);
        return auctionId;
    }
    
    /**
     * @dev Submete uma ordem de swap para o leilão atual
     * @param tokenIn Token de entrada
     * @param tokenOut Token de saída
     * @param amountIn Quantidade de entrada
     * @param minAmountOut Quantidade mínima de saída
     * @param maxGasPrice Preço máximo de gas aceito
     * @param swapData Dados do swap
     */
    function submitOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxGasPrice,
        bytes calldata swapData
    ) external nonReentrant {
        require(currentAuctionId > 0, "No active auction");
        require(auctions[currentAuctionId].isActive, "Auction not active");
        require(block.timestamp < auctions[currentAuctionId].endTime, "Auction ended");
        require(amountIn > 0, "Invalid amount");
        require(tokenIn != tokenOut, "Same tokens");
        
        // Verificar se o usuário já submeteu uma ordem neste leilão
        require(!auctions[currentAuctionId].hasBid[msg.sender], "Already submitted");
        
        // Verificar limite de ordens por leilão
        require(auctionOrders[currentAuctionId].length < MAX_AUCTION_SIZE, "Auction full");
        
        // Criar ordem
        SwapOrder memory order = SwapOrder({
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            maxGasPrice: maxGasPrice,
            swapData: swapData
        });
        
        // Adicionar ordem ao leilão
        auctionOrders[currentAuctionId].push(order);
        auctions[currentAuctionId].hasBid[msg.sender] = true;
        auctions[currentAuctionId].totalBids++;
        
        emit OrderSubmitted(currentAuctionId, msg.sender, tokenIn, tokenOut, amountIn);
        
        // Verificar se o leilão deve ser finalizado
        if (auctionOrders[currentAuctionId].length >= MIN_AUCTION_SIZE ||
            block.timestamp >= auctions[currentAuctionId].endTime) {
            _finalizeAuction(currentAuctionId);
        }
    }
    
    /**
     * @dev Finaliza um leilão e executa as ordens
     * @param auctionId ID do leilão
     */
    function finalizeAuction(uint256 auctionId) 
        external 
        auctionExists(auctionId)
        auctionActive(auctionId)
        auctionNotSettled(auctionId)
    {
        require(block.timestamp >= auctions[auctionId].endTime || 
                auctionOrders[auctionId].length >= MIN_AUCTION_SIZE, 
                "Cannot finalize yet");
        
        _finalizeAuction(auctionId);
    }
    
    /**
     * @dev Finaliza um leilão internamente
     * @param auctionId ID do leilão
     */
    function _finalizeAuction(uint256 auctionId) internal {
        require(!auctions[auctionId].isSettled, "Already settled");
        
        auctions[auctionId].isActive = false;
        auctions[auctionId].isSettled = true;
        
        SwapOrder[] storage orders = auctionOrders[auctionId];
        uint256 totalVolume = 0;
        
        // Calcular volume total
        for (uint256 i = 0; i < orders.length; i++) {
            totalVolume += orders[i].amountIn;
        }
        
        // Executar ordens em ordem aleatória (baseada no hash do bloco)
        _executeOrdersRandomly(auctionId);
        
        emit AuctionSettled(auctionId, orders.length, totalVolume);
    }
    
    /**
     * @dev Executa ordens em ordem pseudo-aleatória
     * @param auctionId ID do leilão
     */
    function _executeOrdersRandomly(uint256 auctionId) internal {
        SwapOrder[] storage orders = auctionOrders[auctionId];
        uint256 orderCount = orders.length;
        
        // Usar hash do bloco para determinar ordem de execução
        bytes32 seed = keccak256(abi.encodePacked(blockhash(block.number - 1), auctionId));
        
        // Criar array de índices
        uint256[] memory indices = new uint256[](orderCount);
        for (uint256 i = 0; i < orderCount; i++) {
            indices[i] = i;
        }
        
        // Shuffle usando Fisher-Yates
        for (uint256 i = orderCount - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(seed, i))) % (i + 1);
            (indices[i], indices[j]) = (indices[j], indices[i]);
        }
        
        // Executar ordens na ordem determinada
        for (uint256 i = 0; i < orderCount; i++) {
            uint256 orderIndex = indices[i];
            SwapOrder storage order = orders[orderIndex];
            
            // Verificar se o gas price atual está dentro do limite
            if (tx.gasprice <= order.maxGasPrice) {
                _executeOrder(order);
            }
        }
    }
    
    /**
     * @dev Executa uma ordem individual
     * @param order Ordem a ser executada
     */
    function _executeOrder(SwapOrder storage order) internal {
        // Aqui você integraria com o DEX principal
        // Por enquanto, apenas emitimos um evento
        // Na implementação real, você chamaria o contrato LoraDEX
        
        // Exemplo de integração:
        // ILoraDEX dex = ILoraDEX(dexAddress);
        // dex.swap(order.tokenIn, order.amountIn, order.minAmountOut);
        
        // Transferir tokens do usuário para o contrato
        // IERC20(order.tokenIn).transferFrom(order.user, address(this), order.amountIn);
        
        // Executar swap
        // uint256 amountOut = dex.swap(order.tokenIn, order.amountIn, order.minAmountOut);
        
        // Transferir tokens de saída para o usuário
        // IERC20(order.tokenOut).transfer(order.user, amountOut);
    }
    
    /**
     * @dev Retorna informações do leilão
     * @param auctionId ID do leilão
     * @return startTime Tempo de início
     * @return endTime Tempo de fim
     * @return totalBids Total de bids
     * @return isActive Se está ativo
     * @return isSettled Se foi finalizado
     */
    function getAuctionInfo(uint256 auctionId) 
        external 
        view 
        auctionExists(auctionId)
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 totalBids,
            bool isActive,
            bool isSettled
        )
    {
        Auction storage auction = auctions[auctionId];
        return (
            auction.startTime,
            auction.endTime,
            auction.totalBids,
            auction.isActive,
            auction.isSettled
        );
    }
    
    /**
     * @dev Retorna ordens de um leilão
     * @param auctionId ID do leilão
     * @return orders Array de ordens
     */
    function getAuctionOrders(uint256 auctionId) 
        external 
        view 
        auctionExists(auctionId)
        returns (SwapOrder[] memory orders)
    {
        return auctionOrders[auctionId];
    }
    
    /**
     * @dev Verifica se um usuário já submeteu ordem no leilão
     * @param auctionId ID do leilão
     * @param user Endereço do usuário
     * @return hasSubmitted Verdadeiro se já submeteu
     */
    function hasUserSubmitted(uint256 auctionId, address user) 
        external 
        view 
        auctionExists(auctionId)
        returns (bool hasSubmitted)
    {
        return auctions[auctionId].hasBid[user];
    }
    
    /**
     * @dev Retorna estatísticas do leilão atual
     * @return auctionId ID do leilão atual
     * @return orderCount Número de ordens
     * @return timeRemaining Tempo restante
     * @return isActive Se está ativo
     */
    function getCurrentAuctionStats() 
        external 
        view 
        returns (
            uint256 auctionId,
            uint256 orderCount,
            uint256 timeRemaining,
            bool isActive
        )
    {
        if (currentAuctionId == 0) {
            return (0, 0, 0, false);
        }
        
        auctionId = currentAuctionId;
        orderCount = auctionOrders[auctionId].length;
        isActive = auctions[auctionId].isActive;
        
        if (isActive && block.timestamp < auctions[auctionId].endTime) {
            timeRemaining = auctions[auctionId].endTime - block.timestamp;
        } else {
            timeRemaining = 0;
        }
        
        return (auctionId, orderCount, timeRemaining, isActive);
    }
    
    /**
     * @dev Atualiza configurações do contrato
     * @param _auctionDuration Nova duração do leilão
     * @param _minAuctionSize Novo tamanho mínimo
     * @param _maxAuctionSize Novo tamanho máximo
     */
    function updateConfig(
        uint256 _auctionDuration,
        uint256 _minAuctionSize,
        uint256 _maxAuctionSize
    ) external onlyOwner {
        require(_auctionDuration > 0, "Invalid duration");
        require(_minAuctionSize <= _maxAuctionSize, "Invalid sizes");
        require(_maxAuctionSize <= 1000, "Max size too large");
        
        // Atualizar constantes (em uma implementação real, você usaria variáveis de estado)
        // AUCTION_DURATION = _auctionDuration;
        // MIN_AUCTION_SIZE = _minAuctionSize;
        // MAX_AUCTION_SIZE = _maxAuctionSize;
    }
} 