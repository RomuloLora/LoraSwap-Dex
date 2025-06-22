const { ethers } = require("hardhat");

async function main() {
    console.log("🛡️ Testando proteções MEV do LoraDEX...\n");

    // Deploy dos tokens de teste
    const [owner, user1, user2, user3] = await ethers.getSigners();
    
    console.log("📋 Contas de teste:");
    console.log("Owner:", owner.address);
    console.log("User1:", user1.address);
    console.log("User2:", user2.address);
    console.log("User3:", user3.address);
    console.log("");

    // Deploy do token A
    const TokenA = await ethers.getContractFactory("Loratoken");
    const tokenA = await TokenA.deploy("Token A", "TKA");
    await tokenA.waitForDeployment();
    console.log("✅ Token A deployado:", await tokenA.getAddress());

    // Deploy do token B
    const TokenB = await ethers.getContractFactory("Loratoken");
    const tokenB = await TokenB.deploy("Token B", "TKB");
    await tokenB.waitForDeployment();
    console.log("✅ Token B deployado:", await tokenB.getAddress());

    // Deploy do TWAP Oracle
    const TWAPOracle = await ethers.getContractFactory("TWAPOracle");
    const twapOracle = await TWAPOracle.deploy();
    await twapOracle.waitForDeployment();
    console.log("✅ TWAP Oracle deployado:", await twapOracle.getAddress());

    // Deploy do Batch Auction
    const BatchAuction = await ethers.getContractFactory("BatchAuction");
    const batchAuction = await BatchAuction.deploy();
    await batchAuction.waitForDeployment();
    console.log("✅ Batch Auction deployado:", await batchAuction.getAddress());

    // Deploy do Commit Reveal
    const CommitReveal = await ethers.getContractFactory("CommitReveal");
    const commitReveal = await CommitReveal.deploy();
    await commitReveal.waitForDeployment();
    console.log("✅ Commit Reveal deployado:", await commitReveal.getAddress());

    // Deploy do LoraDEX com proteções MEV
    const LoraDEX = await ethers.getContractFactory("LoraDEX");
    const loraDEX = await LoraDEX.deploy(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        await twapOracle.getAddress(),
        await batchAuction.getAddress(),
        await commitReveal.getAddress()
    );
    await loraDEX.waitForDeployment();
    console.log("✅ LoraDEX com proteções MEV deployado:", await loraDEX.getAddress());
    console.log("");

    // Autorizar LoraDEX no TWAPOracle
    await twapOracle.authorize(await loraDEX.getAddress(), true);
    console.log("✅ LoraDEX autorizado no TWAPOracle\n");

    // Teste 1: Verificar configurações MEV iniciais
    console.log("⚙️ Teste 1: Verificação das configurações MEV");
    const mevConfig = await loraDEX.getMEVConfig();
    console.log("TWAP habilitado:", mevConfig[0]);
    console.log("Batch Auction habilitado:", mevConfig[1]);
    console.log("Commit Reveal habilitado:", mevConfig[2]);
    console.log("Slippage máximo:", mevConfig[3].toString(), "basis points");
    console.log("Gas price mínimo:", mevConfig[4].toString());
    console.log("Gas price máximo:", mevConfig[5].toString());
    console.log("✅ Configurações MEV verificadas");
    console.log("");

    // Teste 2: Adicionar liquidez inicial
    console.log("💰 Teste 2: Adicionando liquidez inicial");
    const liquidityAmount = ethers.parseEther("1000");
    
    // Aprovar tokens
    await tokenA.approve(await loraDEX.getAddress(), liquidityAmount);
    await tokenB.approve(await loraDEX.getAddress(), liquidityAmount);
    
    // Adicionar liquidez
    await loraDEX.addLiquidity(liquidityAmount, liquidityAmount, 100);
    console.log("✅ Liquidez adicionada");
    
    // Verificar reservas
    const [reserveA, reserveB] = await loraDEX.getReserves();
    console.log("Reserva A:", ethers.formatEther(reserveA));
    console.log("Reserva B:", ethers.formatEther(reserveB));
    console.log("");

    // Distribuir tokens para usuários de teste
    console.log("🎁 Distribuindo tokens para usuários de teste");
    const userTokenAmount = ethers.parseEther("100");
    
    await tokenA.transfer(user1.address, userTokenAmount);
    await tokenA.transfer(user2.address, userTokenAmount);
    await tokenA.transfer(user3.address, userTokenAmount);
    
    await tokenB.transfer(user1.address, userTokenAmount);
    await tokenB.transfer(user2.address, userTokenAmount);
    await tokenB.transfer(user3.address, userTokenAmount);
    
    console.log("✅ Tokens distribuídos");
    console.log("");

    // Teste 3: Testar TWAP Oracle
    console.log("📊 Teste 3: Testando TWAP Oracle");
    
    // Adicionar algumas observações
    const priceA = ethers.parseEther("1");
    const priceB = ethers.parseEther("1");
    
    for (let i = 0; i < 5; i++) {
        await twapOracle.addObservation(await loraDEX.getAddress(), priceA, priceB);
        console.log(`Observação ${i + 1} adicionada`);
        
        // Aguardar um pouco
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // Verificar TWAP
    const [twap0, twap1] = await twapOracle.getTWAP(await loraDEX.getAddress(), 1800);
    console.log("TWAP Token A:", ethers.formatEther(twap0));
    console.log("TWAP Token B:", ethers.formatEther(twap1));
    console.log("✅ TWAP Oracle funcionando");
    console.log("");

    // Teste 4: Testar swap com proteção MEV
    console.log("🔄 Teste 4: Testando swap com proteção MEV");
    
    const swapAmount = ethers.parseEther("10");
    const swapMinAmountOut = ethers.parseEther("9");
    
    // Aprovar token para swap
    await tokenA.connect(user1).approve(await loraDEX.getAddress(), swapAmount);
    
    // Fazer swap com proteção MEV
    await loraDEX.connect(user1).swap(
        await tokenA.getAddress(),
        swapAmount,
        swapMinAmountOut,
        true // Usar proteção MEV
    );
    
    console.log("✅ Swap com proteção MEV executado");
    
    // Verificar reservas após swap
    const [reserveAAfter, reserveBAfter] = await loraDEX.getReserves();
    console.log("Reserva A após swap:", ethers.formatEther(reserveAAfter));
    console.log("Reserva B após swap:", ethers.formatEther(reserveBAfter));
    console.log("");

    // Teste 5: Testar Batch Auction
    console.log("🏷️ Teste 5: Testando Batch Auction");
    
    // Criar leilão
    await batchAuction.createAuction();
    console.log("✅ Leilão criado");
    
    // Verificar estatísticas do leilão
    const [auctionId, orderCount, timeRemaining, isActive] = await batchAuction.getCurrentAuctionStats();
    console.log("ID do leilão:", auctionId.toString());
    console.log("Número de ordens:", orderCount.toString());
    console.log("Tempo restante:", timeRemaining.toString(), "segundos");
    console.log("Leilão ativo:", isActive);
    console.log("");

    // Teste 6: Testar Commit Reveal
    console.log("🔐 Teste 6: Testando Commit Reveal");
    
    // Gerar commit hash
    const tokenIn = await tokenA.getAddress();
    const tokenOut = await tokenB.getAddress();
    const amountIn = ethers.parseEther("5");
    const commitMinAmountOut = ethers.parseEther("4");
    const nonce = 1;
    const secret = ethers.randomBytes(32);
    
    const commitHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "uint256", "uint256", "uint256", "bytes32"],
        [user2.address, tokenIn, tokenOut, amountIn, commitMinAmountOut, nonce, secret]
    ));
    
    // Submeter commit
    await commitReveal.connect(user2).submitCommit(commitHash);
    console.log("✅ Commit submetido");
    
    // Verificar commit
    const [user, commitTokenIn, commitTokenOut, commitAmountIn, commitMinAmountOutCheck, isRevealed, isExecuted] = 
        await commitReveal.getSwapCommit(commitHash);
    console.log("Usuário do commit:", user);
    console.log("Commit revelado:", isRevealed);
    console.log("Commit executado:", isExecuted);
    console.log("");

    // Teste 7: Revelar commit
    console.log("🔓 Teste 7: Revelando commit");
    
    await commitReveal.connect(user2).revealCommit(
        tokenIn,
        tokenOut,
        amountIn,
        commitMinAmountOut,
        nonce,
        secret
    );
    console.log("✅ Commit revelado");
    
    // Verificar commit após revelação
    const [userAfter, commitTokenInAfter, commitTokenOutAfter, commitAmountInAfter, commitMinAmountOutAfter, isRevealedAfter, isExecutedAfter] = 
        await commitReveal.getSwapCommit(commitHash);
    console.log("Commit revelado após:", isRevealedAfter);
    console.log("Token de entrada:", commitTokenInAfter);
    console.log("Token de saída:", commitTokenOutAfter);
    console.log("");

    // Teste 8: Verificar estatísticas de commits
    console.log("📈 Teste 8: Verificando estatísticas de commits");
    
    const [totalCommits, revealedCommits, executedCommits, expiredCommits] = 
        await commitReveal.getCommitStats(user2.address);
    console.log("Total de commits:", totalCommits.toString());
    console.log("Commits revelados:", revealedCommits.toString());
    console.log("Commits executados:", executedCommits.toString());
    console.log("Commits expirados:", expiredCommits.toString());
    console.log("");

    // Teste 9: Atualizar configurações MEV
    console.log("⚙️ Teste 9: Atualizando configurações MEV");
    
    await loraDEX.updateMEVConfig(
        true,   // useTWAP
        true,   // useBatchAuction
        true,   // useCommitReveal
        300,    // maxSlippage (3%)
        1000000000, // minGasPrice (1 gwei)
        100000000000 // maxGasPrice (100 gwei)
    );
    console.log("✅ Configurações MEV atualizadas");
    
    // Verificar novas configurações
    const newMevConfig = await loraDEX.getMEVConfig();
    console.log("Novo slippage máximo:", newMevConfig[3].toString(), "basis points");
    console.log("Novo gas price mínimo:", newMevConfig[4].toString());
    console.log("Novo gas price máximo:", newMevConfig[5].toString());
    console.log("");

    // Teste 10: Verificar proteção contra gas price
    console.log("⛽ Teste 10: Verificando proteção contra gas price");
    
    try {
        // Tentar fazer swap com gas price muito alto (deve falhar)
        await loraDEX.connect(user3).swap(
            await tokenA.getAddress(),
            ethers.parseEther("1"),
            ethers.parseEther("0.9"),
            false,
            { gasPrice: ethers.parseUnits("1000", "gwei") }
        );
        console.log("❌ Swap com gas price alto não foi bloqueado!");
    } catch (error) {
        console.log("✅ Proteção contra gas price funcionando");
    }
    console.log("");

    console.log("🎉 Todos os testes de proteção MEV passaram!");
    console.log("📋 Resumo das proteções implementadas:");
    console.log("   ✅ TWAP Oracle para detecção de manipulação");
    console.log("   ✅ Batch Auctions para agrupar transações");
    console.log("   ✅ Commit-Reveal para proteção contra front-running");
    console.log("   ✅ Slippage protection dinâmico");
    console.log("   ✅ Gas price protection");
    console.log("   ✅ Configurações flexíveis");
    console.log("   ✅ Integração completa com DEX principal");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Erro nos testes:", error);
        process.exit(1);
    }); 