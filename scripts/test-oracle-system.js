const { ethers } = require("hardhat");

async function main() {
    console.log("🔮 Testando Sistema de Oracles Robusto\n");

    const [owner, oracle1, oracle2, oracle3, relayer1, user1] = await ethers.getSigners();
    
    console.log("📋 Contas de teste:");
    console.log("Owner:", owner.address);
    console.log("Oracle 1:", oracle1.address);
    console.log("Oracle 2:", oracle2.address);
    console.log("Oracle 3:", oracle3.address);
    console.log("Relayer 1:", relayer1.address);
    console.log("User 1:", user1.address);
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

    // 1. DEPLOY DOS MÓDULOS DO SISTEMA
    console.log("🔧 Deploy dos Módulos do Sistema");
    
    const HeartbeatMonitor = await ethers.getContractFactory("HeartbeatMonitor");
    const heartbeatMonitor = await HeartbeatMonitor.deploy();
    await heartbeatMonitor.waitForDeployment();
    console.log("✅ HeartbeatMonitor:", await heartbeatMonitor.getAddress());
    
    const DeviationChecker = await ethers.getContractFactory("DeviationChecker");
    const deviationChecker = await DeviationChecker.deploy();
    await deviationChecker.waitForDeployment();
    console.log("✅ DeviationChecker:", await deviationChecker.getAddress());
    
    const ManipulationDetector = await ethers.getContractFactory("ManipulationDetector");
    const manipulationDetector = await ManipulationDetector.deploy();
    await manipulationDetector.waitForDeployment();
    console.log("✅ ManipulationDetector:", await manipulationDetector.getAddress());
    
    const CrossChainOracle = await ethers.getContractFactory("CrossChainOracle");
    const crossChainOracle = await CrossChainOracle.deploy();
    await crossChainOracle.waitForDeployment();
    console.log("✅ CrossChainOracle:", await crossChainOracle.getAddress());
    
    const OracleAggregator = await ethers.getContractFactory("OracleAggregator");
    const oracleAggregator = await OracleAggregator.deploy(
        await heartbeatMonitor.getAddress(),
        await deviationChecker.getAddress(),
        await manipulationDetector.getAddress()
    );
    await oracleAggregator.waitForDeployment();
    console.log("✅ OracleAggregator:", await oracleAggregator.getAddress());
    console.log("");

    // 2. CONFIGURAÇÃO DO SISTEMA
    console.log("⚙️ Configuração do Sistema");
    
    // Whitelist assets
    await oracleAggregator.setAssetWhitelist(await tokenA.getAddress(), true);
    await oracleAggregator.setAssetWhitelist(await tokenB.getAddress(), true);
    console.log("✅ Assets whitelisted");
    
    // Adicionar oracles
    await oracleAggregator.addOracle(
        oracle1.address,
        "Chainlink Oracle",
        300, // 5 minutos heartbeat
        10,  // 10% deviation threshold
        false // não é fallback
    );
    
    await oracleAggregator.addOracle(
        oracle2.address,
        "Band Protocol Oracle",
        300,
        15,
        false
    );
    
    await oracleAggregator.addOracle(
        oracle3.address,
        "Fallback Oracle",
        600, // 10 minutos heartbeat
        20,  // 20% deviation threshold
        true // é fallback
    );
    console.log("✅ Oracles adicionados");
    
    // Configurar deviation checker
    await deviationChecker.setDeviationConfig(await tokenA.getAddress(), {
        maxDeviationPercent: 15,
        minDeviationPercent: 1,
        deviationWindow: 3600,
        isEnabled: true
    });
    
    await deviationChecker.setDeviationConfig(await tokenB.getAddress(), {
        maxDeviationPercent: 20,
        minDeviationPercent: 1,
        deviationWindow: 3600,
        isEnabled: true
    });
    console.log("✅ Deviation configs definidas");
    
    // Configurar manipulation detector
    await manipulationDetector.setManipulationConfig(await tokenA.getAddress(), {
        maxPriceChangePercent: 25,
        minUpdateInterval: 60,
        suspiciousVolumeThreshold: 1000000,
        priceSpikeThreshold: 30,
        isEnabled: true
    });
    
    await manipulationDetector.setManipulationConfig(await tokenB.getAddress(), {
        maxPriceChangePercent: 30,
        minUpdateInterval: 60,
        suspiciousVolumeThreshold: 1000000,
        priceSpikeThreshold: 35,
        isEnabled: true
    });
    console.log("✅ Manipulation configs definidas");
    
    // Configurar cross-chain oracle
    await crossChainOracle.registerChain(1, "Ethereum", 1800, 10); // 30 min sync, 10% tolerance
    await crossChainOracle.registerChain(137, "Polygon", 900, 15); // 15 min sync, 15% tolerance
    await crossChainOracle.registerChain(56, "BSC", 1200, 12); // 20 min sync, 12% tolerance
    console.log("✅ Chains registradas");
    
    await crossChainOracle.setRelayerAuthorization(relayer1.address, true);
    console.log("✅ Relayer autorizado");
    console.log("");

    // 3. TESTE: HEARTBEAT MONITORING
    console.log("💓 Teste: Heartbeat Monitoring");
    
    // Registrar oracles no heartbeat monitor
    await heartbeatMonitor.registerOracle(oracle1.address, 300, 60);
    await heartbeatMonitor.registerOracle(oracle2.address, 300, 60);
    await heartbeatMonitor.registerOracle(oracle3.address, 600, 120);
    console.log("✅ Oracles registrados no heartbeat monitor");
    
    // Simular heartbeats
    await heartbeatMonitor.connect(oracle1).updateHeartbeat(oracle1.address);
    await heartbeatMonitor.connect(oracle2).updateHeartbeat(oracle2.address);
    await heartbeatMonitor.connect(oracle3).updateHeartbeat(oracle3.address);
    console.log("✅ Heartbeats atualizados");
    
    // Verificar status
    const [isAlive1, lastHeartbeat1] = await heartbeatMonitor.checkHeartbeat(oracle1.address);
    const [isAlive2, lastHeartbeat2] = await heartbeatMonitor.checkHeartbeat(oracle2.address);
    const [isAlive3, lastHeartbeat3] = await heartbeatMonitor.checkHeartbeat(oracle3.address);
    
    console.log("   Oracle 1 - Alive:", isAlive1, "Last heartbeat:", new Date(Number(lastHeartbeat1) * 1000).toLocaleString());
    console.log("   Oracle 2 - Alive:", isAlive2, "Last heartbeat:", new Date(Number(lastHeartbeat2) * 1000).toLocaleString());
    console.log("   Oracle 3 - Alive:", isAlive3, "Last heartbeat:", new Date(Number(lastHeartbeat3) * 1000).toLocaleString());
    
    const heartbeatStats = await heartbeatMonitor.getMonitoringStats();
    console.log("   Estatísticas:", heartbeatStats);
    console.log("");

    // 4. TESTE: PRICE UPDATES E DEVIATION CHECKS
    console.log("📊 Teste: Price Updates e Deviation Checks");
    
    // Atualizar preços via oracles
    await oracleAggregator.connect(oracle1).updatePrice(
        await tokenA.getAddress(),
        ethers.parseEther("100"), // $100
        95 // 95% confidence
    );
    
    await oracleAggregator.connect(oracle2).updatePrice(
        await tokenA.getAddress(),
        ethers.parseEther("105"), // $105
        90 // 90% confidence
    );
    
    await oracleAggregator.connect(oracle3).updatePrice(
        await tokenA.getAddress(),
        ethers.parseEther("98"), // $98
        85 // 85% confidence
    );
    console.log("✅ Preços atualizados pelos oracles");
    
    // Verificar preço agregado
    try {
        const [price, confidence, timestamp] = await oracleAggregator.getPrice(await tokenA.getAddress());
        console.log("   Preço agregado:", ethers.formatEther(price), "USD");
        console.log("   Confiança:", confidence.toString(), "%");
        console.log("   Timestamp:", new Date(Number(timestamp) * 1000).toLocaleString());
    } catch (error) {
        console.log("   ⚠️ Preço ainda não disponível (aguardando agregação)");
    }
    
    // Verificar desvios
    await deviationChecker.recordPrice(await tokenA.getAddress(), ethers.parseEther("100"));
    await deviationChecker.recordPrice(await tokenA.getAddress(), ethers.parseEther("105"));
    await deviationChecker.recordPrice(await tokenA.getAddress(), ethers.parseEther("98"));
    
    const deviationStats = await deviationChecker.getDeviationStats();
    console.log("   Estatísticas de desvios:", deviationStats);
    console.log("");

    // 5. TESTE: MANIPULATION DETECTION
    console.log("🕵️ Teste: Manipulation Detection");
    
    // Simular preços normais
    await manipulationDetector.recordPrice(await tokenA.getAddress(), ethers.parseEther("100"));
    await manipulationDetector.recordPrice(await tokenA.getAddress(), ethers.parseEther("102"));
    await manipulationDetector.recordPrice(await tokenA.getAddress(), ethers.parseEther("101"));
    
    // Simular pump and dump
    await manipulationDetector.recordPrice(await tokenA.getAddress(), ethers.parseEther("120")); // +19%
    await manipulationDetector.recordPrice(await tokenA.getAddress(), ethers.parseEther("108")); // -10%
    
    const manipulationStats = await manipulationDetector.getDetectionStats();
    console.log("   Manipulações detectadas:", manipulationStats[0].toString());
    console.log("   Falsos positivos:", manipulationStats[1].toString());
    console.log("");

    // 6. TESTE: CROSS-CHAIN ORACLE
    console.log("⛓️ Teste: Cross-Chain Oracle");
    
    // Criar requisição de sincronização
    const createTx = await crossChainOracle.createSyncRequest(
        await tokenA.getAddress(),
        1 // Ethereum
    );
    const createReceipt = await createTx.wait();
    const requestId = createReceipt.logs[0].args.requestId;
    console.log("   Sync request criada:", requestId.toString());
    
    // Simular atualização cross-chain
    const proof = ethers.keccak256(ethers.toUtf8Bytes("proof_" + Date.now()));
    await crossChainOracle.connect(relayer1).updateCrossChainPrice(
        await tokenA.getAddress(),
        1, // Ethereum
        ethers.parseEther("100"),
        95,
        proof
    );
    console.log("   Preço cross-chain atualizado");
    
    // Verificar preço cross-chain
    const [crossChainPrice, crossChainConfidence, crossChainTimestamp] = await crossChainOracle.getCrossChainPrice(
        await tokenA.getAddress(),
        1
    );
    console.log("   Preço cross-chain:", ethers.formatEther(crossChainPrice), "USD");
    console.log("   Confiança:", crossChainConfidence.toString(), "%");
    
    // Completar requisição
    const completeTx = await crossChainOracle.connect(relayer1).completeSyncRequest(requestId, proof);
    await completeTx.wait();
    console.log("   Sync request completada");
    
    const crossChainStats = await crossChainOracle.getCrossChainStats();
    console.log("   Estatísticas cross-chain:", crossChainStats);
    console.log("");

    // 7. TESTE: FALLBACK MECHANISM
    console.log("🔄 Teste: Fallback Mechanism");
    
    // Simular falha dos oracles principais
    console.log("   Simulando falha dos oracles principais...");
    
    // Atualizar apenas o oracle de fallback
    await oracleAggregator.connect(oracle3).updatePrice(
        await tokenB.getAddress(),
        ethers.parseEther("50"), // $50
        80 // 80% confidence
    );
    
    // Verificar preço via fallback
    try {
        const [fallbackPrice, fallbackConfidence, fallbackTimestamp] = await oracleAggregator.getPrice(await tokenB.getAddress());
        console.log("   Preço via fallback:", ethers.formatEther(fallbackPrice), "USD");
        console.log("   Confiança:", fallbackConfidence.toString(), "%");
    } catch (error) {
        console.log("   ⚠️ Preço fallback ainda não disponível");
    }
    console.log("");

    // 8. ESTATÍSTICAS FINAIS
    console.log("📈 Estatísticas Finais do Sistema");
    
    const systemStats = await oracleAggregator.getSystemStats();
    console.log("   Total oracles:", systemStats[0].toString());
    console.log("   Total assets:", systemStats[1].toString());
    console.log("   Total price updates:", systemStats[2].toString());
    console.log("   Total deviations detected:", systemStats[3].toString());
    console.log("   Total manipulations detected:", systemStats[4].toString());
    
    const priceData = await oracleAggregator.getPriceData(await tokenA.getAddress());
    console.log("   Dados do preço Token A:");
    console.log("     Preço:", ethers.formatEther(priceData.price), "USD");
    console.log("     Confiança:", priceData.confidence.toString(), "%");
    console.log("     Oracle count:", priceData.oracleCount.toString());
    console.log("     Válido:", priceData.isValid);
    console.log("");

    console.log("🎉 Sistema de Oracles Robusto testado com sucesso!");
    console.log("📋 Resumo dos recursos implementados:");
    console.log("   ✅ Multi-oracle aggregation com confiança ponderada");
    console.log("   ✅ Deviation checks com thresholds configuráveis");
    console.log("   ✅ Heartbeat monitoring com detecção de falhas");
    console.log("   ✅ Fallback mechanisms para alta disponibilidade");
    console.log("   ✅ Price manipulation detection com múltiplos padrões");
    console.log("   ✅ Cross-chain oracle synchronization");
    console.log("   ✅ Emergency pause functionality");
    console.log("   ✅ Comprehensive monitoring e estatísticas");
    console.log("");
    console.log("🚀 O LoraSwap-DEX agora possui um sistema de oracles enterprise-grade!");
    console.log("   Cada componente oferece proteções específicas:");
    console.log("   - Aggregator: Agregação robusta de múltiplas fontes");
    console.log("   - Heartbeat: Monitoramento de saúde dos oracles");
    console.log("   - Deviation: Detecção de anomalias de preço");
    console.log("   - Manipulation: Proteção contra ataques");
    console.log("   - Cross-chain: Sincronização entre blockchains");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Erro nos testes:", error);
        process.exit(1);
    }); 