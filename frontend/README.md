# LoraSwap Frontend

A modern, responsive frontend for the LoraSwap decentralized exchange built with Next.js, React, and TypeScript.

## Features

- 🚀 **Modern UI/UX** - Clean, intuitive interface built with Tailwind CSS
- 🔗 **Wallet Integration** - Seamless wallet connection with RainbowKit
- 💱 **Token Swapping** - Easy token-to-token swaps with real-time price calculations
- 💧 **Liquidity Management** - Add and remove liquidity from pools
- ⚙️ **Advanced Settings** - Customizable slippage tolerance and transaction settings
- 📱 **Responsive Design** - Works perfectly on desktop and mobile devices
- 🔒 **Security First** - Built with security best practices and error handling

## Tech Stack

- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Wallet Integration**: RainbowKit + Wagmi
- **State Management**: React Query
- **UI Components**: Headless UI + Heroicons
- **Animations**: Framer Motion

## Prerequisites

- Node.js 16+ 
- npm or yarn
- Hardhat node running on localhost:8545
- Deployed smart contracts

## Installation

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Set up environment variables**:
   ```bash
   cp .env.example .env.local
   ```
   
   Update the `.env.local` file with your contract addresses:
   ```env
   NEXT_PUBLIC_FACTORY_ADDRESS=0x...
   NEXT_PUBLIC_ROUTER_ADDRESS=0x...
   NEXT_PUBLIC_LORA_TOKEN_ADDRESS=0x...
   NEXT_PUBLIC_LORA_TOKEN2_ADDRESS=0x...
   NEXT_PUBLIC_CHAIN_ID=31337
   NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
   NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id_here
   ```

3. **Update contract addresses** (after deploying contracts):
   ```bash
   node scripts/deploy.js
   ```

## Development

1. **Start the development server**:
   ```bash
   npm run dev
   ```

2. **Open your browser** and navigate to `http://localhost:3000`

3. **Connect your wallet** using MetaMask or any other supported wallet

## Usage

### Swapping Tokens

1. **Select tokens**: Choose the token you want to swap from and to
2. **Enter amount**: Input the amount you want to swap
3. **Review details**: Check the swap details including price impact and fees
4. **Approve tokens**: Approve the router to spend your tokens (first time only)
5. **Execute swap**: Confirm the transaction in your wallet

### Managing Liquidity

1. **Add Liquidity**:
   - Select the token pair
   - Enter amounts for both tokens
   - Review pool share and current reserves
   - Approve tokens and add liquidity

2. **Remove Liquidity**:
   - Enter the amount of LP tokens to burn
   - Review expected token returns
   - Confirm the transaction

### Settings

- **Slippage Tolerance**: Set the maximum acceptable price slippage (0.1% - 50%)
- **Transaction Deadline**: Set how long transactions can be pending
- **Expert Mode**: Enable high slippage trades (use with caution)
- **Multihop**: Enable trades through multiple pools for better rates

## Project Structure

```
src/
├── app/                    # Next.js App Router
│   ├── layout.tsx         # Root layout with providers
│   ├── page.tsx           # Main page component
│   ├── providers.tsx      # Wagmi and RainbowKit providers
│   └── globals.css        # Global styles
├── components/            # React components
│   └── SettingsModal.tsx  # Settings configuration
├── hooks/                 # Custom React hooks
│   └── useDEX.ts         # DEX interaction hooks
└── lib/                  # Utility libraries
    ├── contracts.ts      # Contract ABIs and addresses
    └── wagmi.ts          # Wagmi configuration
```

## Configuration

### Contract Addresses

Update contract addresses in `src/lib/contracts.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
  factory: "0x...",
  router: "0x...",
  loraToken: "0x...",
  loraToken2: "0x...",
} as const;
```

### Network Configuration

Configure supported networks in `src/lib/wagmi.ts`:

```typescript
const chains = [hardhat, localhost, mainnet, sepolia] as const;
```

### WalletConnect

Get a project ID from [WalletConnect Cloud](https://cloud.walletconnect.com/) and update:

```typescript
projectId: 'YOUR_PROJECT_ID',
```

## Building for Production

1. **Build the application**:
   ```bash
   npm run build
   ```

2. **Start the production server**:
   ```bash
   npm start
   ```

## Testing

```bash
# Run type checking
npm run type-check

# Run linting
npm run lint

# Run tests (when implemented)
npm test
```

## Deployment

### Vercel (Recommended)

1. **Connect your repository** to Vercel
2. **Set environment variables** in Vercel dashboard
3. **Deploy** - Vercel will automatically build and deploy

### Other Platforms

1. **Build the application**: `npm run build`
2. **Upload the `.next` folder** to your hosting provider
3. **Set environment variables** on your hosting platform

## Troubleshooting

### Common Issues

1. **"Cannot find module" errors**:
   - Run `npm install` to install missing dependencies
   - Clear node_modules and reinstall: `rm -rf node_modules && npm install`

2. **Wallet connection issues**:
   - Ensure MetaMask is installed and unlocked
   - Check if you're on the correct network
   - Clear browser cache and try again

3. **Transaction failures**:
   - Check your token balance
   - Verify slippage tolerance settings
   - Ensure you have enough ETH for gas fees

4. **Contract interaction errors**:
   - Verify contract addresses are correct
   - Check if contracts are deployed and verified
   - Ensure you're on the correct network

### Debug Mode

Enable debug logging by setting:

```env
NEXT_PUBLIC_DEBUG=true
```

## Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Support

- **Documentation**: Check the main project README
- **Issues**: Report bugs and feature requests on GitHub
- **Discord**: Join our community for support and discussions

## Security

- **Audit**: Smart contracts have been audited
- **Bug Bounty**: Report security vulnerabilities for rewards
- **Best Practices**: Follow security guidelines when contributing

---

Built with ❤️ by the LoraSwap team 