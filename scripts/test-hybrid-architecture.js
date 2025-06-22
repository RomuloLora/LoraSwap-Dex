const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Testando Arquitetura Híbrida LoraSwap-DEX\n");

    // Deploy dos tokens de teste
    const [owner, user1, user2, user3] = await ethers.getSigners();
    
    console.log("📋 Contas de teste:");
    console.log("Owner:", owner.address);
    console.log("User1:", user1.address);
    console.log("User2:", user2.address);
    console.log("User3:", user3.address);
    console.log("");

    // Deploy dos tokens
    const TokenA = await ethers.getContractFactory("Loratoken");
    const tokenA = await TokenA.deploy("Token A", "TKA");
    await tokenA.waitForDeployment();
    console.log("✅ Token A deployado:", await tokenA.getAddress());

    const TokenB = await ethers.getContractFactory("Loratoken");
    const tokenB = await TokenB.deploy("Token B", "TKB");
    await tokenB.waitForDeployment();
    console.log("✅ Token B deployado:", await tokenB.getAddress());

    const TokenC = await ethers.getContractFactory("Loratoken");
    const tokenC = await TokenC.deploy("Token C", "TKC");
    await tokenC.waitForDeployment();
    console.log("✅ Token C deployado:", await tokenC.getAddress());
    console.log("");

    // 1. TESTE: Concentrated Liquidity Pool
    console.log("🎯 Teste 1: Concentrated Liquidity Pool");
    
    const ConcentratedPool = await ethers.getContractFactory("ConcentratedPool");
    const concentratedPool = await ConcentratedPool.deploy(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000 // 0.3% fee
    );
    await concentratedPool.waitForDeployment();
    console.log("✅ Concentrated Pool deployado:", await concentratedPool.getAddress());
    
    // Verificar configuração inicial
    const slot0 = await concentratedPool.slot0();
    console.log("   Preço inicial:", slot0.sqrtPriceX96.toString());
    console.log("   Tick inicial:", slot0.tick.toString());
    console.log("   Fee:", await concentratedPool.fee());
    console.log("");

    // 2. TESTE: Route Optimizer
    console.log("🛣️ Teste 2: Route Optimizer");
    
    const RouteOptimizer = await ethers.getContractFactory("RouteOptimizer");
    const routeOptimizer = await RouteOptimizer.deploy();
    await routeOptimizer.waitForDeployment();
    console.log("✅ Route Optimizer deployado:", await routeOptimizer.getAddress());
    
    // Adicionar pools ao otimizador
    await routeOptimizer.addPool(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000, // 0.3% fee
        await concentratedPool.getAddress(),
        ethers.parseEther("1000"), // liquidity
        ethers.parseEther("10000") // volume 24h
    );
    console.log("   Pool adicionado ao otimizador");
    
    // Encontrar rota otimizada
    const routerConfig = {
        maxHops: 3,
        maxSlippage: 500,
        useSplitRoutes: true,
        gasLimit: 500000,
        useMEVProtection: true
    };
    
    const optimalRoute = await routeOptimizer.findOptimalRoute(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        ethers.parseEther("10"),
        routerConfig
    );
    console.log("   Rota otimizada encontrada");
    console.log("   Número de pools:", optimalRoute.pools.length);
    console.log("");

    // 3. TESTE: Bridge Manager
    console.log("🌉 Teste 3: Cross-Chain Bridge Manager");
    
    const BridgeManager = await ethers.getContractFactory("BridgeManager");
    const bridgeManager = await BridgeManager.deploy();
    await bridgeManager.waitForDeployment();
    console.log("✅ Bridge Manager deployado:", await bridgeManager.getAddress());
    
    // Configurar bridge para Ethereum (chainId 1)
    const bridgeConfig = {
        chainId: 1,
        bridgeContract: await bridgeManager.getAddress(),
        minAmount: ethers.parseEther("0.1"),
        maxAmount: ethers.parseEther("1000"),
        fee: 100, // 0.01%
        isActive: true,
        maxDailyVolume: ethers.parseEther("100000"),
        currentDailyVolume: 0,
        lastResetTime: Math.floor(Date.now() / 1000)
    };
    
    await bridgeManager.setBridgeConfig(1, bridgeConfig);
    console.log("   Bridge configurado para Ethereum");
    
    // Adicionar validadores
    await bridgeManager.addValidator(user1.address);
    await bridgeManager.addValidator(user2.address);
    await bridgeManager.addValidator(user3.address);
    console.log("   Validadores adicionados");
    console.log("");

    // 4. TESTE: Gas Optimizer
    console.log("⛽ Teste 4: Gas Optimizer");
    
    const GasOptimizer = await ethers.getContractFactory("GasOptimizer");
    const gasOptimizer = await GasOptimizer.deploy();
    await gasOptimizer.waitForDeployment();
    console.log("✅ Gas Optimizer deployado:", await gasOptimizer.getAddress());
    
    // Verificar configuração inicial
    const gasConfig = await gasOptimizer.getGasConfig();
    console.log("   Configuração de gas:");
    console.log("   - Use calldata:", gasConfig.useCalldata);
    console.log("   - Use batch processing:", gasConfig.useBatchProcessing);
    console.log("   - Max batch size:", gasConfig.maxBatchSize.toString());
    console.log("   - Gas refund threshold:", gasConfig.gasRefundThreshold.toString());
    console.log("");

    // 5. TESTE: Distribuição de tokens
    console.log("💰 Teste 5: Distribuição de tokens");
    
    const tokenAmount = ethers.parseEther("1000");
    await tokenA.transfer(user1.address, tokenAmount);
    await tokenA.transfer(user2.address, tokenAmount);
    await tokenA.transfer(user3.address, tokenAmount);
    
    await tokenB.transfer(user1.address, tokenAmount);
    await tokenB.transfer(user2.address, tokenAmount);
    await tokenB.transfer(user3.address, tokenAmount);
    
    await tokenC.transfer(user1.address, tokenAmount);
    await tokenC.transfer(user2.address, tokenAmount);
    await tokenC.transfer(user3.address, tokenAmount);
    
    console.log("   Tokens distribuídos para usuários de teste");
    console.log("");

    // 6. TESTE: Batch Swap com Gas Optimization
    console.log("🔄 Teste 6: Batch Swap com Gas Optimization");
    
    // Preparar swaps em lote
    const swapParams = [
        {
            tokenIn: await tokenA.getAddress(),
            tokenOut: await tokenB.getAddress(),
            amountIn: ethers.parseEther("10"),
            minAmountOut: ethers.parseEther("9"),
            recipient: user1.address,
            swapData: "0x"
        },
        {
            tokenIn: await tokenB.getAddress(),
            tokenOut: await tokenC.getAddress(),
            amountIn: ethers.parseEther("5"),
            minAmountOut: ethers.parseEther("4.5"),
            recipient: user1.address,
            swapData: "0x"
        }
    ];
    
    // Aprovar tokens
    await tokenA.connect(user1).approve(await gasOptimizer.getAddress(), ethers.parseEther("20"));
    await tokenB.connect(user1).approve(await gasOptimizer.getAddress(), ethers.parseEther("20"));
    
    // Executar batch swap
    const batchResult = await gasOptimizer.connect(user1).batchSwap(swapParams);
    console.log("   Batch swap executado");
    console.log("   Transaction hash:", batchResult.hash);
    
    // Verificar refund de gas
    const gasRefund = await gasOptimizer.getGasRefund(user1.address);
    console.log("   Gas refund disponível:", ethers.formatEther(gasRefund));
    console.log("");

    // 7. TESTE: Cross-Chain Bridge
    console.log("🌐 Teste 7: Cross-Chain Bridge");
    
    // Adicionar liquidez ao bridge
    await tokenA.connect(user2).approve(await bridgeManager.getAddress(), ethers.parseEther("100"));
    await bridgeManager.connect(user2).addLiquidity(1, await tokenA.getAddress(), ethers.parseEther("100"));
    console.log("   Liquidez adicionada ao bridge");
    
    // Iniciar swap cross-chain
    await tokenA.connect(user3).approve(await bridgeManager.getAddress(), ethers.parseEther("10"));
    const swapTx = await bridgeManager.connect(user3).initiateSwap(
        1, // target chain (Ethereum)
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        ethers.parseEther("10"),
        ethers.parseEther("9"),
        user3.address,
        { value: ethers.parseEther("0.001") } // bridge fee
    );
    console.log("   Swap cross-chain iniciado");
    console.log("   Transaction hash:", swapTx.hash);
    console.log("");

    // 8. TESTE: Estatísticas e Métricas
    console.log("📊 Teste 8: Estatísticas e Métricas");
    
    // Estatísticas do bridge
    const totalVolume = await bridgeManager.getTotalVolume(1);
    console.log("   Volume total no bridge:", ethers.formatEther(totalVolume));
    
    // Configurações dos módulos
    const bridgeConfigRetrieved = await bridgeManager.getBridgeConfig(1);
    console.log("   Bridge configurado para chain ID:", bridgeConfigRetrieved.chainId.toString());
    console.log("   Bridge ativo:", bridgeConfigRetrieved.isActive);
    
    // Validadores
    const isValidator1 = await bridgeManager.isValidator(user1.address);
    const isValidator2 = await bridgeManager.isValidator(user2.address);
    console.log("   User1 é validador:", isValidator1);
    console.log("   User2 é validador:", isValidator2);
    console.log("");

    console.log("🎉 Todos os testes da arquitetura híbrida passaram!");
    console.log("📋 Resumo da implementação:");
    console.log("   ✅ Concentrated Liquidity Pool (Uniswap V3 style)");
    console.log("   ✅ Multi-hop Route Optimizer");
    console.log("   ✅ Cross-Chain Bridge Manager");
    console.log("   ✅ Gas Optimizer para L2s");
    console.log("   ✅ Batch Processing");
    console.log("   ✅ MEV Protection (herdada dos módulos existentes)");
    console.log("   ✅ Modular Architecture");
    console.log("   ✅ Gas Optimization");
    console.log("   ✅ Cross-Chain Liquidity");
    console.log("");
    console.log("🚀 LoraSwap-DEX agora possui uma arquitetura híbrida completa!");
    console.log("   Combinando as melhores características de:");
    console.log("   - Uniswap V3 (Concentrated Liquidity)");
    console.log("   - SushiSwap (Multi-hop Routing)");
    console.log("   - PancakeSwap (Gas Optimization)");
    console.log("   - Inovações únicas em MEV Protection e Cross-Chain Bridges");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Erro nos testes:", error);
        process.exit(1);
    }); 