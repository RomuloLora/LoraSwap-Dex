# 🛡️ Guia de Proteção MEV - LoraDEX

## Visão Geral

O LoraDEX implementa um sistema abrangente de proteção contra MEV (Maximal Extractable Value) que combina múltiplas estratégias para proteger os usuários contra ataques de front-running, sandwich attacks e manipulação de preços.

## 🎯 Proteções Implementadas

### 1. Time-Weighted Average Price (TWAP) Oracle

**Objetivo**: Detectar e prevenir manipulação de preços através de médias ponderadas no tempo.

**Funcionalidades**:
- ✅ Observações de preço em tempo real
- ✅ Cálculo de TWAP com janelas configuráveis (5min - 1h)
- ✅ Detecção automática de desvios de preço
- ✅ Threshold configurável para manipulação (padrão: 5%)
- ✅ Limpeza automática de observações antigas

**Como funciona**:
```solidity
// Adicionar observação de preço
twapOracle.addObservation(poolAddress, priceA, priceB);

// Obter TWAP
(uint256 twap0, uint256 twap1) = twapOracle.getTWAP(poolAddress, 1800);

// Detectar manipulação
bool isManipulated = twapOracle.detectManipulation(poolAddress, currentPrice0, currentPrice1);
```

### 2. Batch Auctions (Leilões em Lote)

**Objetivo**: Agrupar transações para reduzir MEV através de execução em lote.

**Funcionalidades**:
- ✅ Leilões com duração configurável (padrão: 5 minutos)
- ✅ Tamanho mínimo e máximo de lote (10-100 ordens)
- ✅ Execução em ordem pseudo-aleatória (baseada no hash do bloco)
- ✅ Proteção contra gas price excessivo
- ✅ Finalização automática quando condições são atendidas

**Como funciona**:
```solidity
// Criar leilão
uint256 auctionId = batchAuction.createAuction();

// Submeter ordem
batchAuction.submitOrder(tokenIn, tokenOut, amountIn, minAmountOut, maxGasPrice, swapData);

// Finalizar leilão
batchAuction.finalizeAuction(auctionId);
```

### 3. Commit-Reveal Schemes

**Objetivo**: Proteger contra front-running através de commits criptográficos.

**Funcionalidades**:
- ✅ Submissão de commits (hashes) sem revelar detalhes
- ✅ Janela de revelação configurável (padrão: 5 minutos)
- ✅ Delay de execução após commit (padrão: 1 minuto)
- ✅ Limite de commits por usuário (padrão: 10)
- ✅ Limpeza automática de commits expirados

**Como funciona**:
```solidity
// Gerar commit hash
bytes32 commitHash = keccak256(abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, nonce, secret));

// Submeter commit
commitReveal.submitCommit(commitHash);

// Revelar commit (após delay)
commitReveal.revealCommit(tokenIn, tokenOut, amountIn, minAmountOut, nonce, secret);

// Executar swap
commitReveal.executeSwap(commitHash);
```

### 4. Slippage Protection Dinâmico

**Objetivo**: Proteger contra slippage excessivo usando TWAP como referência.

**Funcionalidades**:
- ✅ Comparação com preço TWAP em tempo real
- ✅ Ajuste automático do amountOut baseado no TWAP
- ✅ Threshold configurável (padrão: 5%)
- ✅ Eventos para monitoramento de proteções ativadas

**Como funciona**:
```solidity
// No swap, se MEV protection estiver habilitada
if (useMEVProtection) {
    amountOut = _applyMEVProtection(tokenIn, amountIn, amountOut, reserveIn, reserveOut);
}
```

### 5. Gas Price Protection

**Objetivo**: Prevenir ataques baseados em gas price excessivo.

**Funcionalidades**:
- ✅ Gas price mínimo e máximo configuráveis
- ✅ Rejeição automática de transações com gas price inválido
- ✅ Proteção contra front-running via gas price

**Como funciona**:
```solidity
modifier validGasPrice() {
    require(tx.gasprice >= minGasPrice && tx.gasprice <= maxGasPrice, "Invalid gas price");
    _;
}
```

## ⚙️ Configuração

### Configurações MEV

```solidity
// Atualizar configurações
function updateMEVConfig(
    bool _useTWAP,           // Habilitar TWAP
    bool _useBatchAuction,   // Habilitar Batch Auction
    bool _useCommitReveal,   // Habilitar Commit-Reveal
    uint256 _maxSlippage,    // Slippage máximo (basis points)
    uint256 _minGasPrice,    // Gas price mínimo
    uint256 _maxGasPrice     // Gas price máximo
) external onlyOwner;
```

### Configurações TWAP

```solidity
// Atualizar configurações TWAP
function updateConfig(
    uint32 _windowSize,        // Tamanho da janela (segundos)
    uint32 _minWindowSize,     // Tamanho mínimo
    uint32 _maxWindowSize,     // Tamanho máximo
    uint256 _deviationThreshold // Threshold de desvio (basis points)
) external onlyOwner;
```

## 🔧 Integração com DEX Principal

### Swap com Proteção MEV

```solidity
function swap(
    address tokenIn, 
    uint256 amountIn, 
    uint256 minAmountOut,
    bool useMEVProtection  // Habilitar proteções MEV
) external nonReentrant whenNotPaused validAmount(amountIn) validGasPrice;
```

### Funções de Integração

```solidity
// Batch Auction
function submitBatchOrder(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 maxGasPrice,
    bytes calldata swapData
) external whenNotPaused;

// Commit-Reveal
function submitCommit(bytes32 commitHash) external whenNotPaused;
function revealCommit(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 nonce, bytes32 secret) external whenNotPaused;
function executeCommitSwap(bytes32 commitHash) external whenNotPaused;
```

## 📊 Monitoramento

### Eventos Importantes

```solidity
// TWAP
event ObservationAdded(address indexed pool, uint256 timestamp, uint256 price0, uint256 price1);
event TWAPUpdated(address indexed pool, uint256 twap0, uint256 twap1);
event ManipulationDetected(address indexed pool, uint256 currentPrice, uint256 twapPrice);

// Batch Auction
event AuctionCreated(uint256 indexed auctionId, uint256 startTime, uint256 endTime);
event OrderSubmitted(uint256 indexed auctionId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn);
event AuctionSettled(uint256 indexed auctionId, uint256 totalOrders, uint256 totalVolume);

// Commit-Reveal
event CommitSubmitted(address indexed user, bytes32 indexed commitHash, uint256 timestamp);
event CommitRevealed(address indexed user, bytes32 indexed commitHash, address tokenIn, address tokenOut, uint256 amountIn);
event SwapExecuted(address indexed user, bytes32 indexed commitHash, uint256 amountOut);

// MEV Protection
event MEVProtectionEnabled(string protection, bool enabled);
event SlippageProtectionTriggered(address indexed user, uint256 expectedAmount, uint256 actualAmount);
```

### Funções de Consulta

```solidity
// Configurações MEV
function getMEVConfig() external view returns (bool, bool, bool, uint256, uint256, uint256);

// TWAP
function getTWAP(address pool, uint32 windowSize) external view returns (uint256, uint256);
function getObservationCount(address pool) external view returns (uint256);

// Batch Auction
function getCurrentAuctionStats() external view returns (uint256, uint256, uint256, bool);
function getAuctionInfo(uint256 auctionId) external view returns (uint256, uint256, uint256, bool, bool);

// Commit-Reveal
function getCommitStats(address user) external view returns (uint256, uint256, uint256, uint256);
function canExecuteCommit(bytes32 commitHash) external view returns (bool, string memory);
```

## 🚀 Como Usar

### 1. Swap Simples (sem proteção MEV)

```javascript
// Aprovar token
await tokenA.approve(loraDEX.address, amountIn);

// Fazer swap
await loraDEX.swap(tokenA.address, amountIn, minAmountOut, false);
```

### 2. Swap com Proteção MEV

```javascript
// Aprovar token
await tokenA.approve(loraDEX.address, amountIn);

// Fazer swap com proteção
await loraDEX.swap(tokenA.address, amountIn, minAmountOut, true);
```

### 3. Usar Batch Auction

```javascript
// Submeter ordem para leilão
await loraDEX.submitBatchOrder(
    tokenA.address,
    tokenB.address,
    amountIn,
    minAmountOut,
    maxGasPrice,
    swapData
);
```

### 4. Usar Commit-Reveal

```javascript
// Gerar secret e nonce
const secret = ethers.randomBytes(32);
const nonce = Date.now();

// Gerar commit hash
const commitHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "uint256", "uint256", "uint256", "bytes32"],
    [user.address, tokenA.address, tokenB.address, amountIn, minAmountOut, nonce, secret]
));

// Submeter commit
await loraDEX.submitCommit(commitHash);

// Aguardar delay (1 minuto)
await new Promise(resolve => setTimeout(resolve, 60000));

// Revelar commit
await loraDEX.revealCommit(tokenA.address, tokenB.address, amountIn, minAmountOut, nonce, secret);

// Executar swap
await loraDEX.executeCommitSwap(commitHash);
```

## 🔒 Segurança

### Medidas de Segurança Implementadas

1. **Reentrancy Protection**: Todos os contratos usam `ReentrancyGuard`
2. **Access Control**: Funções críticas protegidas por `Ownable`
3. **Input Validation**: Validação rigorosa de todos os inputs
4. **Gas Optimization**: Otimizações para reduzir custos
5. **Event Logging**: Logs detalhados para auditoria
6. **Emergency Functions**: Funções de emergência para pausar operações

### Recomendações de Segurança

1. **Auditoria**: Sempre audite os contratos antes do deploy
2. **Testes**: Execute testes extensivos em testnet
3. **Monitoramento**: Monitore eventos e logs regularmente
4. **Configuração**: Ajuste configurações conforme necessário
5. **Backup**: Mantenha backups das configurações críticas

## 📈 Performance

### Otimizações Implementadas

1. **Gas Optimization**: Uso eficiente de storage e memory
2. **Batch Processing**: Processamento em lote para reduzir custos
3. **Lazy Loading**: Carregamento sob demanda de dados
4. **Efficient Algorithms**: Algoritmos otimizados para cálculos

### Métricas Esperadas

- **Gas por swap**: ~150,000 - 200,000 gas
- **Gas por commit**: ~50,000 gas
- **Gas por revelação**: ~80,000 gas
- **Latência TWAP**: < 1 segundo
- **Tempo de leilão**: 5 minutos (configurável)

## 🛠️ Manutenção

### Tarefas Regulares

1. **Limpeza de Commits**: Remover commits expirados
2. **Atualização TWAP**: Manter observações atualizadas
3. **Monitoramento**: Verificar eventos e logs
4. **Configuração**: Ajustar parâmetros conforme necessário

### Troubleshooting

1. **Commits não executados**: Verificar se estão dentro da janela de tempo
2. **TWAP não atualizado**: Verificar se há observações suficientes
3. **Leilões não finalizados**: Verificar se há ordens suficientes
4. **Gas price rejeitado**: Verificar configurações de gas price

## 📚 Recursos Adicionais

- [Documentação OpenZeppelin](https://docs.openzeppelin.com/)
- [MEV Research](https://ethereum.org/en/developers/docs/mev/)
- [Flashbots](https://docs.flashbots.net/)
- [Ethereum Gas Optimization](https://ethereum.org/en/developers/docs/gas/)

---

**⚠️ Disclaimer**: Este sistema de proteção MEV é experimental e deve ser testado extensivamente antes do uso em produção. Sempre consulte especialistas de segurança antes do deploy. 