# LoraDEX - Decentralized Exchange Smart Contract

Um DEX (Decentralized Exchange) simples implementado em Solidity, baseado no modelo AMM (Automated Market Maker) com fórmula de produto constante.

## 📋 Descrição

O LoraDEX é um contrato inteligente que permite:
- Adicionar liquidez para pares de tokens
- Realizar swaps entre tokens usando a fórmula x * y = k
- Calcular preços de saída baseados nas reservas atuais

## 🏗️ Arquitetura

### Contratos Principais

- **LoraDEX.sol**: Contrato principal que gerencia o DEX
  - Gerenciamento de reservas de tokens
  - Funções de swap
  - Cálculo de preços usando AMM

### Funcionalidades

1. **Add Liquidity**: Permite aos usuários adicionar liquidez ao pool
2. **Swap**: Permite trocar um token por outro
3. **Price Calculation**: Calcula o preço de saída baseado na fórmula AMM

## 🚀 Instalação e Uso

### Pré-requisitos

- Node.js (versão 16 ou superior)
- npm ou yarn

### Instalação

```bash
# Clone o repositório
git clone <seu-repositorio>
cd LoraSwap-Dex

# Instale as dependências
npm install
```

### Compilação

```bash
# Compile os contratos
npx hardhat compile
```

### Testes

```bash
# Execute os testes
npx hardhat test
```

### Deploy

```bash
# Deploy para rede local
npx hardhat run scripts/deploy.js --network localhost

# Deploy para rede de teste
npx hardhat run scripts/deploy.js --network testnet
```

## 📝 Funcionalidades do Contrato

### Add Liquidity
```solidity
function addLiquidity(uint256 amountA, uint256 amountB) external
```
Adiciona liquidez ao pool. Os usuários devem aprovar o contrato para transferir seus tokens.

### Swap
```solidity
function swap(address tokenIn, uint256 amountIn) external
```
Realiza uma troca de tokens. O usuário especifica qual token está enviando e a quantidade.

### Get Amount Out
```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256)
```
Calcula a quantidade de tokens que serão recebidos em uma troca.

## 🔧 Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
PRIVATE_KEY=sua_chave_privada_aqui
INFURA_URL=sua_url_infura_aqui
ETHERSCAN_API_KEY=sua_chave_etherscan_aqui
```

### Redes Suportadas

- Localhost (desenvolvimento)
- Testnet (Goerli, Sepolia)
- Mainnet (Ethereum)

## 📊 Fórmula AMM

O contrato usa a fórmula de produto constante:
```
(x + Δx) * (y - Δy) = x * y
```

Onde:
- x, y = reservas atuais dos tokens
- Δx = quantidade de entrada
- Δy = quantidade de saída

## 🛡️ Segurança

- Verificações de quantidade mínima
- Proteção contra divisão por zero
- Eventos para auditoria de transações

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🤝 Contribuição

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📞 Contato

Para dúvidas ou sugestões, abra uma issue no repositório.

---

**Nota**: Este é um projeto educacional. Use em produção por sua conta e risco. 