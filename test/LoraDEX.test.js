const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoraDEX", function () {
    let LoraToken, LoraDEX, LoraFactory, LoraRouter;
    let loraToken, loraToken2, loraDEX, loraFactory, loraRouter;
    let owner, addr1, addr2, addr3, addrs;
    let WETH;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
        
        // Deploy tokens
        LoraToken = await ethers.getContractFactory("LoraToken");
        loraToken = await LoraToken.deploy();
        await loraToken.waitForDeployment();
        
        loraToken2 = await LoraToken.deploy();
        await loraToken2.waitForDeployment();
        
        // Deploy factory
        LoraFactory = await ethers.getContractFactory("LoraFactory");
        loraFactory = await LoraFactory.deploy(owner.address);
        await loraFactory.waitForDeployment();
        
        // Deploy router
        LoraRouter = await ethers.getContractFactory("LoraRouter");
        loraRouter = await LoraRouter.deploy(await loraFactory.getAddress(), ethers.ZeroAddress);
        await loraRouter.waitForDeployment();
        
        // Deploy DEX pair
        await loraFactory.createPair(await loraToken.getAddress(), await loraToken2.getAddress());
        const pairAddress = await loraFactory.getPair(await loraToken.getAddress(), await loraToken2.getAddress());
        loraDEX = await ethers.getContractAt("LoraDEX", pairAddress);
        
        // Transfer tokens to users for testing
        await loraToken.transfer(addr1.address, ethers.parseEther("10000"));
        await loraToken.transfer(addr2.address, ethers.parseEther("10000"));
        await loraToken2.transfer(addr1.address, ethers.parseEther("10000"));
        await loraToken2.transfer(addr2.address, ethers.parseEther("10000"));
    });

    describe("Deployment", function () {
        it("Should deploy factory correctly", async function () {
            expect(await loraFactory.owner()).to.equal(owner.address);
            expect(await loraFactory.feeToSetter()).to.equal(owner.address);
        });

        it("Should create pair correctly", async function () {
            const pairAddress = await loraFactory.getPair(await loraToken.getAddress(), await loraToken2.getAddress());
            expect(pairAddress).to.not.equal(ethers.ZeroAddress);
            expect(await loraFactory.allPairsLength()).to.equal(1);
        });

        it("Should initialize pair correctly", async function () {
            expect(await loraDEX.tokenA()).to.equal(await loraToken.getAddress());
            expect(await loraDEX.tokenB()).to.equal(await loraToken2.getAddress());
            expect(await loraDEX.initialized()).to.be.true;
        });
    });

    describe("Liquidity", function () {
        it("Should add liquidity correctly", async function () {
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, addr1.address, deadline);
            
            expect(await loraDEX.balanceOf(addr1.address)).to.be.gt(0);
        });

        it("Should remove liquidity correctly", async function () {
            // First add liquidity
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, addr1.address, deadline);
            
            const liquidity = await loraDEX.balanceOf(addr1.address);
            
            // Then remove liquidity
            await loraDEX.approve(await loraDEX.getAddress(), liquidity);
            await loraDEX.removeLiquidity(liquidity, 0, 0, addr1.address, deadline);
            
            expect(await loraDEX.balanceOf(addr1.address)).to.equal(0);
        });

        it("Should fail to add liquidity with zero amounts", async function () {
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await expect(
                loraDEX.addLiquidity(0, 0, 0, 0, addr1.address, deadline)
            ).to.be.revertedWith("LoraDEX: INSUFFICIENT_LIQUIDITY_MINTED");
        });
    });

    describe("Swapping", function () {
        beforeEach(async function () {
            // Add initial liquidity
            const amountA = ethers.parseEther("10000");
            const amountB = ethers.parseEther("10000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, owner.address, deadline);
        });

        it("Should calculate correct amount out", async function () {
            const amountIn = ethers.parseEther("100");
            const reserveIn = ethers.parseEther("10000");
            const reserveOut = ethers.parseEther("10000");
            
            const amountOut = await loraDEX.getAmountOut(amountIn, reserveIn, reserveOut);
            expect(amountOut).to.be.gt(0);
            expect(amountOut).to.be.lt(amountIn); // Due to fees
        });

        it("Should calculate correct amount in", async function () {
            const amountOut = ethers.parseEther("100");
            const reserveIn = ethers.parseEther("10000");
            const reserveOut = ethers.parseEther("10000");
            
            const amountIn = await loraDEX.getAmountIn(amountOut, reserveIn, reserveOut);
            expect(amountIn).to.be.gt(amountOut); // Due to fees
        });

        it("Should perform swap correctly", async function () {
            const swapAmount = ethers.parseEther("100");

            // 1. Transfira tokens para addr1
            await loraToken.transfer(addr1.address, swapAmount);

            // 2. addr1 faz approve para o DEX
            await loraToken.connect(addr1).approve(await loraDEX.getAddress(), swapAmount);

            // 3. Saldo antes do swap
            const balanceBefore = await loraToken2.balanceOf(addr1.address);

            // 4. addr1 faz o swap
            await loraDEX.connect(addr1).swap(0, swapAmount, addr1.address, "0x");

            // 5. Saldo depois do swap
            const balanceAfter = await loraToken2.balanceOf(addr1.address);
            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should fail swap with insufficient liquidity", async function () {
            const largeAmount = ethers.parseEther("50000"); // More than reserves
            
            await loraToken.approve(await loraDEX.getAddress(), largeAmount);
            
            await expect(
                loraDEX.swap(0, largeAmount, addr1.address, "0x")
            ).to.be.revertedWith("LoraDEX: INSUFFICIENT_LIQUIDITY");
        });

        it("Should fail swap with zero output amount", async function () {
            await expect(
                loraDEX.swap(0, 0, addr1.address, "0x")
            ).to.be.revertedWith("LoraDEX: INSUFFICIENT_OUTPUT_AMOUNT");
        });
    });

    describe("Router Functions", function () {
        beforeEach(async function () {
            // Add initial liquidity
            const amountA = ethers.parseEther("10000");
            const amountB = ethers.parseEther("10000");
            
            await loraToken.approve(await loraRouter.getAddress(), amountA);
            await loraToken2.approve(await loraRouter.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraRouter.addLiquidity(
                await loraToken.getAddress(),
                await loraToken2.getAddress(),
                amountA,
                amountB,
                0,
                0,
                owner.address,
                deadline
            );
        });

        it("Should add liquidity through router", async function () {
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            await loraToken.approve(await loraRouter.getAddress(), amountA);
            await loraToken2.approve(await loraRouter.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            const result = await loraRouter.addLiquidity(
                await loraToken.getAddress(),
                await loraToken2.getAddress(),
                amountA,
                amountB,
                0,
                0,
                addr1.address,
                deadline
            );
            
            expect(result[2]).to.be.gt(0); // liquidity tokens
        });

        it("Should calculate amounts out correctly", async function () {
            const amountIn = ethers.parseEther("100");
            const path = [await loraToken.getAddress(), await loraToken2.getAddress()];
            
            const amounts = await loraRouter.getAmountsOut(amountIn, path);
            expect(amounts[0]).to.equal(amountIn);
            expect(amounts[1]).to.be.gt(0);
        });

        it("Should perform swap through router", async function () {
            const amountIn = ethers.parseEther("100");
            const path = [await loraToken.getAddress(), await loraToken2.getAddress()];
            
            await loraToken.approve(await loraRouter.getAddress(), amountIn);
            
            const balanceBefore = await loraToken2.balanceOf(addr1.address);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraRouter.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                addr1.address,
                deadline
            );
            
            const balanceAfter = await loraToken2.balanceOf(addr1.address);
            expect(balanceAfter).to.be.gt(balanceBefore);
        });
    });

    describe("Factory Management", function () {
        it("Should allow fee setter to update fee to", async function () {
            await loraFactory.setFeeTo(addr1.address);
            expect(await loraFactory.feeTo()).to.equal(addr1.address);
        });

        it("Should allow fee setter to update fee to setter", async function () {
            await loraFactory.setFeeToSetter(addr1.address);
            expect(await loraFactory.feeToSetter()).to.equal(addr1.address);
        });

        it("Should not allow non-fee setter to update fee to", async function () {
            await expect(
                loraFactory.connect(addr1).setFeeTo(addr2.address)
            ).to.be.revertedWith("LoraFactory: FORBIDDEN");
        });

        it("Should check pair existence correctly", async function () {
            const exists = await loraFactory.pairExists(await loraToken.getAddress(), await loraToken2.getAddress());
            expect(exists).to.be.true;
            
            const nonExistent = await loraFactory.pairExists(addr1.address, addr2.address);
            expect(nonExistent).to.be.false;
        });
    });

    describe("Edge Cases", function () {
        it("Should handle identical addresses in pair creation", async function () {
            await expect(
                loraFactory.createPair(await loraToken.getAddress(), await loraToken.getAddress())
            ).to.be.revertedWith("LoraFactory: IDENTICAL_ADDRESSES");
        });

        it("Should handle zero address in pair creation", async function () {
            await expect(
                loraFactory.createPair(ethers.ZeroAddress, await loraToken.getAddress())
            ).to.be.revertedWith("LoraFactory: ZERO_ADDRESS");
        });

        it("Should prevent duplicate pair creation", async function () {
            await expect(
                loraFactory.createPair(await loraToken.getAddress(), await loraToken2.getAddress())
            ).to.be.revertedWith("LoraFactory: PAIR_EXISTS");
        });

        it("Should handle expired deadline", async function () {
            const expiredDeadline = Math.floor(Date.now() / 1000) - 3600;
            await expect(
                loraDEX.addLiquidity(1000, 1000, 0, 0, addr1.address, expiredDeadline)
            ).to.be.revertedWith("LoraDEX: EXPIRED");
        });
    });

    describe("Events", function () {
        it("Should emit Mint event", async function () {
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await expect(
                loraDEX.addLiquidity(amountA, amountB, 0, 0, addr1.address, deadline)
            ).to.emit(loraDEX, "Mint");
        });

        it("Should emit Swap event", async function () {
            // Add liquidity first
            const amountA = ethers.parseEther("10000");
            const amountB = ethers.parseEther("10000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, owner.address, deadline);
            
            // Then swap
            const swapAmount = ethers.parseEther("100");
            await loraToken.approve(await loraDEX.getAddress(), swapAmount);
            
            await expect(
                loraDEX.swap(0, swapAmount, addr1.address, "0x")
            ).to.emit(loraDEX, "Swap");
        });
    });
}); 