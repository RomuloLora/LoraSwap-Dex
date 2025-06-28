# LoraSwap DEX

A complete decentralized exchange (DEX) built on Ethereum with automated market making (AMM) functionality, featuring both smart contracts and a modern frontend interface.

## 🚀 Features

### Smart Contracts
- **AMM Core**: Automated market making with x*y=k formula
- **Factory Pattern**: Create and manage trading pairs
- **Router**: Simplified interface for token swaps and liquidity operations
- **Custom Token**: ERC20 token with minting and transfer controls
- **Security**: Reentrancy protection, deadline enforcement, slippage tolerance

### Frontend
- **Modern UI**: Clean, responsive interface built with Next.js and Tailwind CSS
- **Wallet Integration**: Seamless connection with RainbowKit and Wagmi
- **Real-time Updates**: Live price calculations and balance updates
- **Advanced Features**: Slippage settings, transaction deadlines, expert mode
- **Mobile Responsive**: Works perfectly on all devices

## 🏗️ Architecture

```
LoraSwap-Dex/
├── contracts/           # Smart contracts
│   ├── LoraDEX.sol     # Core AMM pair contract
│   ├── LoraFactory.sol # Factory for creating pairs
│   ├── LoraRouter.sol  # Router for simplified interactions
│   └── LoraToken.sol   # Custom ERC20 token
├── frontend/           # Next.js frontend application
│   ├── src/
│   │   ├── app/        # Next.js App Router
│   │   ├── components/ # React components
│   │   ├── hooks/      # Custom React hooks
│   │   └── lib/        # Utilities and configurations
│   └── package.json
├── test/               # Smart contract tests
├── scripts/            # Deployment and utility scripts
└── hardhat.config.js   # Hardhat configuration
```

## 🛠️ Tech Stack

### Smart Contracts
- **Solidity**: ^0.8.20
- **OpenZeppelin**: ^5.3.0
- **Hardhat**: Development and testing framework
- **Ethers.js**: Blockchain interaction

### Frontend
- **Next.js**: 14 with App Router
- **React**: 18 with TypeScript
- **Tailwind CSS**: Styling
- **Wagmi**: React hooks for Ethereum
- **RainbowKit**: Wallet connection
- **Framer Motion**: Animations

## 📋 Prerequisites

- Node.js 16+
- npm or yarn
- MetaMask or compatible wallet
- Git

## 🚀 Quick Start

### 1. Clone and Install

```bash
git clone <repository-url>
cd LoraSwap-Dex
npm run install:all
```

### 2. Start Development Environment

```bash
# Start both Hardhat node and frontend
npm run dev

# Or start them separately:
npm run node        # Start Hardhat node
npm run frontend    # Start frontend in another terminal
```

### 3. Deploy Contracts

```bash
# Deploy to local network
npm run deploy

# Update frontend with contract addresses
cd frontend && node scripts/deploy.js
```

### 4. Access the Application

- **Frontend**: http://localhost:3000
- **Hardhat Node**: http://localhost:8545

## 📖 Usage Guide

### For Users

1. **Connect Wallet**: Click "Connect Wallet" and approve the connection
2. **Swap Tokens**: 
   - Select tokens to swap
   - Enter amount
   - Review details and confirm
3. **Add Liquidity**:
   - Switch to "Liquidity" tab
   - Enter token amounts
   - Approve and add liquidity
4. **Remove Liquidity**:
   - Enter LP token amount
   - Confirm removal

### For Developers

#### Smart Contract Development

```bash
# Compile contracts
npm run compile

# Run tests
npm test

# Deploy to local network
npm run deploy

# Deploy to testnet
npm run deploy -- --network sepolia
```

#### Frontend Development

```bash
# Start frontend only
npm run frontend

# Build for production
npm run frontend:build

# Type checking
cd frontend && npm run type-check
```

## 🔧 Configuration

### Environment Variables

Create `.env` file in the root directory:

```env
# Network Configuration
PRIVATE_KEY=your_private_key_here
INFURA_URL=your_infura_url_here
ETHERSCAN_API_KEY=your_etherscan_key_here

# Frontend (in frontend/.env.local)
NEXT_PUBLIC_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_ROUTER_ADDRESS=0x...
NEXT_PUBLIC_LORA_TOKEN_ADDRESS=0x...
NEXT_PUBLIC_LORA_TOKEN2_ADDRESS=0x...
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id_here
```

### Network Configuration

Update `hardhat.config.js` for different networks:

```javascript
module.exports = {
  networks: {
    hardhat: {
      chainId: 31337
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: process.env.INFURA_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

## 🧪 Testing

### Smart Contract Tests

```bash
# Run all tests
npm test

# Run specific test file
npx hardhat test test/LoraDEX.test.js

# Run with coverage
npx hardhat coverage
```

### Frontend Tests

```bash
cd frontend
npm run type-check
npm run lint
```

## 📦 Deployment

### Smart Contracts

1. **Local Development**:
   ```bash
   npm run deploy
   ```

2. **Testnet Deployment**:
   ```bash
   npm run deploy -- --network sepolia
   ```

3. **Mainnet Deployment**:
   ```bash
   npm run deploy -- --network mainnet
   ```

### Frontend

1. **Vercel (Recommended)**:
   - Connect repository to Vercel
   - Set environment variables
   - Deploy automatically

2. **Manual Deployment**:
   ```bash
   cd frontend
   npm run build
   npm start
   ```

## 🔍 Contract Verification

```bash
# Verify on Etherscan
npx hardhat verify --network sepolia CONTRACT_ADDRESS
```

## 📊 Contract Addresses

After deployment, update the addresses in `frontend/src/lib/contracts.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
  factory: "0x...",
  router: "0x...",
  loraToken: "0x...",
  loraToken2: "0x...",
} as const;
```

## 🛡️ Security

- **Reentrancy Protection**: All external calls are protected
- **Slippage Tolerance**: Configurable slippage protection
- **Deadline Enforcement**: Transactions expire after set time
- **Input Validation**: Comprehensive parameter validation
- **Access Control**: Owner-only functions for critical operations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines

- Follow Solidity best practices
- Write comprehensive tests
- Update documentation
- Use conventional commits
- Ensure mobile responsiveness

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [Wiki](../../wiki)
- **Issues**: Report bugs on [GitHub Issues](../../issues)
- **Discussions**: Join our [GitHub Discussions](../../discussions)
- **Discord**: Join our community server

## 🙏 Acknowledgments

- Inspired by Uniswap V2
- Built with OpenZeppelin contracts
- UI components from Headless UI
- Icons from Heroicons

---

**Built with ❤️ by the LoraSwap Team**

*For questions, support, or contributions, please reach out to our community!* 