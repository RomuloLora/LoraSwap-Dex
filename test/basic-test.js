const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Basic Setup Test", function () {
    let LoraToken, LoraDEX, LoraFactory, LoraRouter;
    let loraToken, loraToken2, loraDEX, loraFactory, loraRouter;
    let owner, addr1;

    beforeEach(async function () {
        console.log("=== Starting Basic Setup Test ===");
        
        [owner, addr1] = await ethers.getSigners();
        console.log("Owner address:", owner.address);
        console.log("Addr1 address:", addr1.address);
        
        // Deploy tokens
        console.log("Deploying tokens...");
        LoraToken = await ethers.getContractFactory("LoraToken");
        loraToken = await LoraToken.deploy();
        await loraToken.waitForDeployment();
        const token1Address = await loraToken.getAddress();
        console.log("Token1 deployed at:", token1Address);
        
        loraToken2 = await LoraToken.deploy();
        await loraToken2.waitForDeployment();
        const token2Address = await loraToken2.getAddress();
        console.log("Token2 deployed at:", token2Address);
        
        // Verify addresses are not null
        expect(token1Address).to.not.equal("0x0000000000000000000000000000000000000000");
        expect(token2Address).to.not.equal("0x0000000000000000000000000000000000000000");
        
        // Deploy factory
        console.log("Deploying factory...");
        LoraFactory = await ethers.getContractFactory("LoraFactory");
        loraFactory = await LoraFactory.deploy(owner.address);
        await loraFactory.waitForDeployment();
        const factoryAddress = await loraFactory.getAddress();
        console.log("Factory deployed at:", factoryAddress);
        expect(factoryAddress).to.not.equal("0x0000000000000000000000000000000000000000");
        
        // Deploy router
        console.log("Deploying router...");
        LoraRouter = await ethers.getContractFactory("LoraRouter");
        loraRouter = await LoraRouter.deploy(factoryAddress, ethers.ZeroAddress);
        await loraRouter.waitForDeployment();
        const routerAddress = await loraRouter.getAddress();
        console.log("Router deployed at:", routerAddress);
        expect(routerAddress).to.not.equal("0x0000000000000000000000000000000000000000");
        
        // Create pair
        console.log("Creating pair...");
        await loraFactory.createPair(token1Address, token2Address);
        const pairAddress = await loraFactory.getPair(token1Address, token2Address);
        console.log("Pair created at:", pairAddress);
        expect(pairAddress).to.not.equal("0x0000000000000000000000000000000000000000");
        
        // Get DEX contract
        loraDEX = await ethers.getContractAt("LoraDEX", pairAddress);
        console.log("DEX contract obtained for pair:", pairAddress);
        
        console.log("=== Basic Setup Complete ===");
    });

    it("Should have valid addresses", async function () {
        const token1Address = await loraToken.getAddress();
        const token2Address = await loraToken2.getAddress();
        const factoryAddress = await loraFactory.getAddress();
        const routerAddress = await loraRouter.getAddress();
        const pairAddress = await loraFactory.getPair(token1Address, token2Address);
        
        console.log("Final verification:");
        console.log("- Token1:", token1Address);
        console.log("- Token2:", token2Address);
        console.log("- Factory:", factoryAddress);
        console.log("- Router:", routerAddress);
        console.log("- Pair:", pairAddress);
        
        expect(token1Address).to.not.equal("0x0000000000000000000000000000000000000000");
        expect(token2Address).to.not.equal("0x0000000000000000000000000000000000000000");
        expect(factoryAddress).to.not.equal("0x0000000000000000000000000000000000000000");
        expect(routerAddress).to.not.equal("0x0000000000000000000000000000000000000000");
        expect(pairAddress).to.not.equal("0x0000000000000000000000000000000000000000");
    });

    it("Should be able to call basic functions", async function () {
        const token1Address = await loraToken.getAddress();
        const token2Address = await loraToken2.getAddress();
        
        // Test factory functions
        const pairExists = await loraFactory.pairExists(token1Address, token2Address);
        console.log("Pair exists:", pairExists);
        expect(pairExists).to.be.true;
        
        // Test token functions
        const token1Name = await loraToken.name();
        const token2Name = await loraToken2.name();
        console.log("Token1 name:", token1Name);
        console.log("Token2 name:", token2Name);
        expect(token1Name).to.equal("Lora Token");
        expect(token2Name).to.equal("Lora Token");
        
        // Test DEX functions
        const dexTokenA = await loraDEX.tokenA();
        const dexTokenB = await loraDEX.tokenB();
        console.log("DEX TokenA:", dexTokenA);
        console.log("DEX TokenB:", dexTokenB);
        
        // Check that both tokens are present (order doesn't matter)
        expect([dexTokenA, dexTokenB]).to.include(token1Address);
        expect([dexTokenA, dexTokenB]).to.include(token2Address);
    });

    it("Should add liquidity successfully", async function () {
        const token1Address = await loraToken.getAddress();
        const token2Address = await loraToken2.getAddress();
        
        // Ensure transfer cooldown is disabled
        await loraToken.setTransferCooldown(0);
        await loraToken2.setTransferCooldown(0);
        
        // Transfer tokens to owner for testing
        await loraToken.transfer(owner.address, ethers.parseEther("10000"));
        await loraToken2.transfer(owner.address, ethers.parseEther("10000"));
        
        // Approve DEX to spend tokens
        const amountA = ethers.parseEther("1000");
        const amountB = ethers.parseEther("1000");
        await loraToken.approve(await loraDEX.getAddress(), amountA);
        await loraToken2.approve(await loraDEX.getAddress(), amountB);
        
        // Transfer tokens to DEX before calling addLiquidity
        await loraToken.transfer(await loraDEX.getAddress(), amountA);
        await loraToken2.transfer(await loraDEX.getAddress(), amountB);
        
        // Add liquidity
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        await loraDEX.addLiquidity(amountA, amountB, 0, 0, owner.address, deadline);
        
        // Verify LP tokens were minted
        const lpBalance = await loraDEX.balanceOf(owner.address);
        console.log("LP tokens minted:", lpBalance.toString());
        expect(lpBalance).to.be.gt(0);
        
        // Verify reserves were updated
        const [reserveA, reserveB] = await loraDEX.getReserves();
        console.log("Reserves after adding liquidity - A:", reserveA.toString(), "B:", reserveB.toString());
        expect(reserveA).to.be.gt(0);
        expect(reserveB).to.be.gt(0);
    });
}); 