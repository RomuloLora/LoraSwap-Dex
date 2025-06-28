# LoraSwap DEX

[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue.svg)](https://soliditylang.org/)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.24.3-orange.svg)](https://hardhat.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

LoraSwap é um DEX (Decentralized Exchange) completo baseado em AMM (Automated Market Maker) inspirado no Uniswap V2, construído com Solidity e Hardhat.

## 🚀 Características

- **AMM (Automated Market Maker)**: Sistema de criação de mercado automatizado
- **Liquidez Automática**: Adição e remoção de liquidez com tokens LP
- **Swaps Seguros**: Troca de tokens com proteção contra slippage
- **Factory Pattern**: Criação dinâmica de pares de trading
- **Router Inteligente**: Interface simplificada para operações
- **Token ERC-20 Avançado**: Token com funcionalidades de mint, burn e pausa
- **Testes Completos**: Cobertura de testes abrangente
- **Verificação de Contratos**: Suporte para verificação no Etherscan

## 📋 Pré-requisitos

- Node.js (v16 ou superior)
- npm ou yarn
- Git

## 🛠️ Instalação

1. **Clone o repositório**
```bash
git clone https://github.com/seu-usuario/loraswap-dex.git
cd loraswap-dex
```

2. **Instale as dependências**
```bash
npm install
```

3. **Configure as variáveis de ambiente**
```bash
cp env.example .env
# Edite o arquivo .env com suas configurações
```

4. **Compile os contratos**
```bash
npm run compile
```

## 🧪 Testes

Execute os testes para verificar se tudo está funcionando:

```bash
# Executar todos os testes
npm test

# Executar testes com cobertura
npm run test:coverage

# Executar testes específicos
npx hardhat test test/LoraToken.test.js
npx hardhat test test/LoraDEX.test.js
```

## 🚀 Deploy

### Deploy Local
```bash
# Iniciar nó local
npm run node

# Em outro terminal, fazer deploy
npm run deploy:local
```

### Deploy em Testnet
```bash
npm run deploy:testnet
```

### Deploy em Mainnet
```bash
npm run deploy:mainnet
```

## 📁 Estrutura do Projeto

```
LoraSwap-Dex/
├── contracts/                 # Contratos inteligentes
│   ├── LoraToken.sol         # Token ERC-20 principal
│   ├── LoraDEX.sol           # Contrato principal do DEX
│   ├── LoraFactory.sol       # Factory para criar pares
│   └── LoraRouter.sol        # Router para operações
├── test/                     # Testes
│   ├── LoraToken.test.js     # Testes do token
│   └── LoraDEX.test.js       # Testes do DEX
├── scripts/                  # Scripts de deploy
│   └── deploy.js             # Script principal de deploy
├── hardhat.config.js         # Configuração do Hardhat
├── package.json              # Dependências e scripts
└── README.md                 # Este arquivo
```

## 🔧 Contratos

### LoraToken
- Token ERC-20 com funcionalidades avançadas
- Sistema de minting controlado
- Cooldown de transferências
- Funcionalidade de pausa
- Queima de tokens

### LoraDEX
- AMM baseado em Uniswap V2
- Cálculo automático de preços
- Adição/remoção de liquidez
- Swaps seguros com proteção

### LoraFactory
- Criação dinâmica de pares
- Gerenciamento de taxas
- Registro de todos os pares

### LoraRouter
- Interface simplificada para operações
- Cálculo de rotas de swap
- Operações de liquidez

## 🔒 Segurança

- **ReentrancyGuard**: Proteção contra ataques de reentrância
- **Ownable**: Controle de acesso para funções administrativas
- **SafeERC20**: Operações seguras com tokens ERC-20
- **Validações**: Verificações rigorosas de entrada
- **Testes**: Cobertura abrangente de casos de uso

## 📊 Funcionalidades

### Swaps
- Swap exato de entrada
- Swap exato de saída
- Proteção contra slippage
- Cálculo automático de preços

### Liquidez
- Adição de liquidez
- Remoção de liquidez
- Tokens LP (Liquidity Provider)
- Recompensas de liquidez

### Gestão de Tokens
- Minting controlado
- Burning de tokens
- Transferências com cooldown
- Pausa de emergência

## 🧪 Testes

O projeto inclui testes abrangentes para:

- ✅ Deploy de contratos
- ✅ Operações de token
- ✅ Swaps de tokens
- ✅ Gestão de liquidez
- ✅ Casos de erro
- ✅ Eventos emitidos
- ✅ Segurança e permissões

## 🔧 Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` baseado no `env.example`:

```env
# Network Configuration
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR-PROJECT-ID
TESTNET_RPC_URL=https://sepolia.infura.io/v3/YOUR-PROJECT-ID

# Private Key (NEVER commit this to version control)
PRIVATE_KEY=your_private_key_here

# API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here

# Gas Reporting
REPORT_GAS=true
```

### Redes Suportadas

- **Localhost**: Desenvolvimento local
- **Sepolia**: Testnet Ethereum
- **Mainnet**: Ethereum principal

## 📈 Gas Optimization

O projeto inclui otimizações de gas:

- Compilador otimizado (200 runs)
- ViaIR habilitado
- Operações eficientes
- Relatórios de gas automáticos

## 🔍 Verificação de Contratos

Os contratos são automaticamente verificados no Etherscan após o deploy:

```bash
npm run verify
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## ⚠️ Disclaimer

Este software é fornecido "como está", sem garantias de qualquer tipo. Use por sua conta e risco.

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/seu-usuario/loraswap-dex/issues)
- **Documentação**: [Wiki](https://github.com/seu-usuario/loraswap-dex/wiki)
- **Discord**: [LoraSwap Community](https://discord.gg/loraswap)

## 🚀 Roadmap

- [ ] Interface web (React/Next.js)
- [ ] Integração com mais redes (Polygon, BSC)
- [ ] Sistema de governança
- [ ] Yield farming
- [ ] Analytics avançados
- [ ] Mobile app

---

**LoraSwap DEX** - Construindo o futuro do DeFi 🚀 