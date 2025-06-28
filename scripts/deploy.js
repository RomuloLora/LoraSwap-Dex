const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    // Deploy LoraToken
    console.log("\n=== Deploying LoraToken ===");
    const LoraToken = await ethers.getContractFactory("LoraToken");
    const loraToken = await LoraToken.deploy();
    await loraToken.waitForDeployment();
    console.log("LoraToken deployed to:", await loraToken.getAddress());

    // Deploy LoraFactory
    console.log("\n=== Deploying LoraFactory ===");
    const LoraFactory = await ethers.getContractFactory("LoraFactory");
    const loraFactory = await LoraFactory.deploy(deployer.address);
    await loraFactory.waitForDeployment();
    console.log("LoraFactory deployed to:", await loraFactory.getAddress());

    // Deploy LoraRouter
    console.log("\n=== Deploying LoraRouter ===");
    const LoraRouter = await ethers.getContractFactory("LoraRouter");
    // Using zero address as WETH for now (can be updated later)
    const loraRouter = await LoraRouter.deploy(await loraFactory.getAddress(), ethers.ZeroAddress);
    await loraRouter.waitForDeployment();
    console.log("LoraRouter deployed to:", await loraRouter.getAddress());

    // Deploy a second token for testing pairs
    console.log("\n=== Deploying Second Token ===");
    const loraToken2 = await LoraToken.deploy();
    await loraToken2.waitForDeployment();
    console.log("Second token deployed to:", await loraToken2.getAddress());

    // Create a pair
    console.log("\n=== Creating First Pair ===");
    const tx = await loraFactory.createPair(await loraToken.getAddress(), await loraToken2.getAddress());
    await tx.wait();
    const pairAddress = await loraFactory.getPair(await loraToken.getAddress(), await loraToken2.getAddress());
    console.log("Pair created at:", pairAddress);

    // Get pair contract
    const LoraDEX = await ethers.getContractFactory("LoraDEX");
    const loraDEX = LoraDEX.attach(pairAddress);

    // Add initial liquidity
    console.log("\n=== Adding Initial Liquidity ===");
    const liquidityAmount = ethers.parseEther("10000"); // 10,000 tokens each
    
    // Approve tokens
    await loraToken.approve(await loraDEX.getAddress(), liquidityAmount);
    await loraToken2.approve(await loraDEX.getAddress(), liquidityAmount);
    
    // Add liquidity
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const addLiquidityTx = await loraDEX.addLiquidity(
        liquidityAmount,
        liquidityAmount,
        0, // amountAMin
        0, // amountBMin
        deployer.address,
        deadline
    );
    await addLiquidityTx.wait();
    console.log("Initial liquidity added successfully");

    // Verify contracts on Etherscan (if not on localhost)
    const network = await ethers.provider.getNetwork();
    if (network.chainId !== 31337) { // Not localhost
        console.log("\n=== Verifying Contracts on Etherscan ===");
        
        try {
            await hre.run("verify:verify", {
                address: await loraToken.getAddress(),
                constructorArguments: [],
            });
            console.log("LoraToken verified on Etherscan");
        } catch (error) {
            console.log("LoraToken verification failed:", error.message);
        }

        try {
            await hre.run("verify:verify", {
                address: await loraFactory.getAddress(),
                constructorArguments: [deployer.address],
            });
            console.log("LoraFactory verified on Etherscan");
        } catch (error) {
            console.log("LoraFactory verification failed:", error.message);
        }

        try {
            await hre.run("verify:verify", {
                address: await loraRouter.getAddress(),
                constructorArguments: [await loraFactory.getAddress(), ethers.ZeroAddress],
            });
            console.log("LoraRouter verified on Etherscan");
        } catch (error) {
            console.log("LoraRouter verification failed:", error.message);
        }

        try {
            await hre.run("verify:verify", {
                address: await loraToken2.getAddress(),
                constructorArguments: [],
            });
            console.log("Second token verified on Etherscan");
        } catch (error) {
            console.log("Second token verification failed:", error.message);
        }
    }

    // Print deployment summary
    console.log("\n=== Deployment Summary ===");
    console.log("Network:", network.name);
    console.log("Deployer:", deployer.address);
    console.log("LoraToken:", await loraToken.getAddress());
    console.log("LoraFactory:", await loraFactory.getAddress());
    console.log("LoraRouter:", await loraRouter.getAddress());
    console.log("Second Token:", await loraToken2.getAddress());
    console.log("First Pair:", pairAddress);
    console.log("Initial Liquidity: 10,000 tokens each");

    // Save deployment info to file
    const deploymentInfo = {
        network: network.name,
        chainId: network.chainId,
        deployer: deployer.address,
        contracts: {
            loraToken: await loraToken.getAddress(),
            loraFactory: await loraFactory.getAddress(),
            loraRouter: await loraRouter.getAddress(),
            secondToken: await loraToken2.getAddress(),
            firstPair: pairAddress
        },
        deploymentTime: new Date().toISOString()
    };

    const fs = require('fs');
    fs.writeFileSync(
        `deployment-${network.chainId}.json`,
        JSON.stringify(deploymentInfo, null, 2)
    );
    console.log(`\nDeployment info saved to: deployment-${network.chainId}.json`);

    // Print next steps
    console.log("\n=== Next Steps ===");
    console.log("1. Update frontend with contract addresses");
    console.log("2. Test the DEX functionality");
    console.log("3. Add more liquidity pairs");
    console.log("4. Deploy to mainnet when ready");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 