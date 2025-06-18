const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Iniciando deploy...");
    
    const [deployer] = await ethers.getSigners();
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Saldo:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");
    
    // 1. Deploy do LoraToken
    console.log("\n📄 Fazendo deploy do LoraToken...");
    const LoraToken = await ethers.getContractFactory("LoraToken");
    const loraToken = await LoraToken.deploy();
    await loraToken.waitForDeployment();
    const loraTokenAddress = await loraToken.getAddress();
    console.log("✅ LoraToken:", loraTokenAddress);
    
    // 2. Deploy do LoraDEX
    console.log("\n📄 Fazendo deploy do LoraDEX...");
    const LoraDEX = await ethers.getContractFactory("LoraDEX");
    const loraDEX = await LoraDEX.deploy(loraTokenAddress, loraTokenAddress); // Usando mesmo token para teste
    await loraDEX.waitForDeployment();
    const loraDEXAddress = await loraDEX.getAddress();
    console.log("✅ LoraDEX:", loraDEXAddress);
    
    console.log("\n🎉 Deploy concluído!");
}

main().catch((error) => {
    console.error("❌ Erro no deploy:", error);
    process.exit(1);
}); 