const { ethers } = require("hardhat");

async function main() {
    console.log("🏗️ Testando Design Patterns em Solidity (Versão Simplificada)\n");

    const [owner, user1, user2, user3] = await ethers.getSigners();
    
    console.log("📋 Contas de teste:");
    console.log("Owner:", owner.address);
    console.log("User1:", user1.address);
    console.log("User2:", user2.address);
    console.log("User3:", user3.address);
    console.log("");

    // Deploy dos tokens de teste
    const TokenA = await ethers.getContractFactory("Loratoken");
    const tokenA = await TokenA.deploy("Token A", "TKA");
    await tokenA.waitForDeployment();

    const TokenB = await ethers.getContractFactory("Loratoken");
    const tokenB = await TokenB.deploy("Token B", "TKB");
    await tokenB.waitForDeployment();

    console.log("✅ Tokens deployados:");
    console.log("Token A:", await tokenA.getAddress());
    console.log("Token B:", await tokenB.getAddress());
    console.log("");

    // 1. TESTE: Factory Pattern
    console.log("🏭 Teste 1: Factory Pattern");
    
    const PoolFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactory = await PoolFactory.deploy();
    await poolFactory.waitForDeployment();
    console.log("✅ PoolFactory deployado:", await poolFactory.getAddress());
    
    // Deploy ConcentratedPool como template
    const ConcentratedPool = await ethers.getContractFactory("ConcentratedPool");
    const concentratedPoolTemplate = await ConcentratedPool.deploy(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000
    );
    await concentratedPoolTemplate.waitForDeployment();
    
    // Adicionar template à factory
    await poolFactory.addPoolTemplate(
        "concentrated",
        await concentratedPoolTemplate.getAddress(),
        [100, 500, 3000, 10000] // fees suportados
    );
    console.log("   Template 'concentrated' adicionado");
    
    // Criar pool usando factory
    const newPool = await poolFactory.createConcentratedPool(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000
    );
    console.log("   Pool criado via factory:", newPool.hash);
    
    // Verificar estatísticas
    const factoryStats = await poolFactory.getFactoryStats();
    console.log("   Total de pools:", factoryStats[0].toString());
    console.log("   Total de templates:", factoryStats[1].toString());
    console.log("");

    // 2. TESTE: Proxy Pattern
    console.log("🔄 Teste 2: Proxy Pattern");
    
    // Deploy da implementação
    const TestImplementation = await ethers.getContractFactory("ConcentratedPool");
    const implementation = await TestImplementation.deploy(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000
    );
    await implementation.waitForDeployment();
    
    // Deploy do proxy
    const UpgradeableProxy = await ethers.getContractFactory("UpgradeableProxy");
    const proxy = await UpgradeableProxy.deploy(
        await implementation.getAddress(),
        owner.address
    );
    await proxy.waitForDeployment();
    console.log("✅ Proxy deployado:", await proxy.getAddress());
    
    // Verificar implementação
    const currentImplementation = await proxy.implementation();
    console.log("   Implementação atual:", currentImplementation);
    
    // Deploy do ProxyAdmin
    const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
    const proxyAdmin = await ProxyAdmin.deploy();
    await proxyAdmin.waitForDeployment();
    console.log("✅ ProxyAdmin deployado:", await proxyAdmin.getAddress());
    console.log("");

    // 3. TESTE: Registry Pattern
    console.log("📋 Teste 3: Registry Pattern");
    
    const PoolRegistry = await ethers.getContractFactory("PoolRegistry");
    const poolRegistry = await PoolRegistry.deploy();
    await poolRegistry.waitForDeployment();
    console.log("✅ PoolRegistry deployado:", await poolRegistry.getAddress());
    
    // Registrar tokens
    await poolRegistry.registerToken(
        await tokenA.getAddress(),
        "TKA",
        "Token A",
        18
    );
    await poolRegistry.registerToken(
        await tokenB.getAddress(),
        "TKB",
        "Token B",
        18
    );
    console.log("   Tokens registrados");
    
    // Registrar pool (usar endereço fictício para teste)
    const testPoolAddress = "0x1234567890123456789012345678901234567890";
    
    await poolRegistry.registerPool(
        testPoolAddress,
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        3000,
        "concentrated",
        await poolFactory.getAddress()
    );
    console.log("   Pool registrado:", testPoolAddress);
    
    // Registrar serviço
    await poolRegistry.connect(user1).registerService(
        "Test Service",
        "1.0.0",
        "Serviço de teste",
        ["test", "demo"]
    );
    console.log("   Serviço registrado");
    
    // Verificar estatísticas
    const registryStats = await poolRegistry.getRegistryStats();
    console.log("   Estatísticas do Registry:");
    console.log("     Total pools:", registryStats[0].toString());
    console.log("     Total serviços:", registryStats[1].toString());
    console.log("     Total tokens:", registryStats[2].toString());
    console.log("     Pools ativos:", registryStats[3].toString());
    console.log("     Serviços ativos:", registryStats[4].toString());
    console.log("     Tokens whitelisted:", registryStats[5].toString());
    console.log("");

    // 4. TESTE: Strategy Pattern
    console.log("🎯 Teste 4: Strategy Pattern");
    
    const PricingStrategy = await ethers.getContractFactory("PricingStrategy");
    const pricingStrategy = await PricingStrategy.deploy();
    await pricingStrategy.waitForDeployment();
    console.log("✅ PricingStrategy deployado:", await pricingStrategy.getAddress());
    
    // Deploy das estratégias de pricing
    const ConstantProductPricing = await ethers.getContractFactory("ConstantProductPricing");
    const constantProductPricing = await ConstantProductPricing.deploy();
    await constantProductPricing.waitForDeployment();
    
    const TWAPPricing = await ethers.getContractFactory("TWAPPricing");
    const twapPricing = await TWAPPricing.deploy();
    await twapPricing.waitForDeployment();
    
    const OraclePricing = await ethers.getContractFactory("OraclePricing");
    const oraclePricing = await OraclePricing.deploy();
    await oraclePricing.waitForDeployment();
    
    console.log("✅ Estratégias de pricing deployadas:");
    console.log("   ConstantProductPricing:", await constantProductPricing.getAddress());
    console.log("   TWAPPricing:", await twapPricing.getAddress());
    console.log("   OraclePricing:", await oraclePricing.getAddress());
    
    // Registrar estratégias
    await pricingStrategy.registerStrategy(
        "constant_product",
        await constantProductPricing.getAddress(),
        "AMM com produto constante"
    );
    
    await pricingStrategy.registerStrategy(
        "twap",
        await twapPricing.getAddress(),
        "Time-Weighted Average Price"
    );
    
    await pricingStrategy.registerStrategy(
        "oracle",
        await oraclePricing.getAddress(),
        "Pricing baseado em oracle"
    );
    
    console.log("   Estratégias registradas");
    
    // Testar cálculo de preço
    const priceResult1 = await pricingStrategy.calculatePrice(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        "constant_product"
    );
    console.log("   Preço AMM:", ethers.formatEther(priceResult1[0]), "Confiança:", priceResult1[1].toString());
    
    const priceResult2 = await pricingStrategy.calculatePrice(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        "twap"
    );
    console.log("   Preço TWAP:", ethers.formatEther(priceResult2[0]), "Confiança:", priceResult2[1].toString());
    
    const priceResult3 = await pricingStrategy.calculatePrice(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        "oracle"
    );
    console.log("   Preço Oracle:", ethers.formatEther(priceResult3[0]), "Confiança:", priceResult3[1].toString());
    
    // Testar preço ponderado
    const weightedResult = await pricingStrategy.calculateWeightedPrice(
        await tokenA.getAddress(),
        await tokenB.getAddress()
    );
    console.log("   Preço ponderado:", ethers.formatEther(weightedResult[0]), "Confiança total:", weightedResult[1].toString());
    
    // Verificar estatísticas
    const strategyStats = await pricingStrategy.getStrategyStats();
    console.log("   Estatísticas das estratégias:");
    console.log("     Total estratégias:", strategyStats[0].toString());
    console.log("     Estratégias ativas:", strategyStats[1].toString());
    console.log("     Total price feeds:", strategyStats[2].toString());
    console.log("");

    console.log("🎉 Design Patterns testados com sucesso!");
    console.log("📋 Resumo dos padrões implementados:");
    console.log("   ✅ Factory Pattern - Criação dinâmica de pools");
    console.log("   ✅ Proxy Pattern - Upgradeability de contratos");
    console.log("   ✅ Registry Pattern - Discovery de pools e serviços");
    console.log("   ✅ Strategy Pattern - Algoritmos de pricing flexíveis");
    console.log("");
    console.log("🚀 LoraSwap-DEX possui uma arquitetura robusta e modular!");
    console.log("   Cada padrão oferece benefícios específicos:");
    console.log("   - Factory: Criação flexível de pools");
    console.log("   - Proxy: Atualizações sem perda de estado");
    console.log("   - Registry: Descoberta e organização");
    console.log("   - Strategy: Flexibilidade de pricing");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Erro nos testes:", error);
        process.exit(1);
    }); 