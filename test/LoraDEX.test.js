const { expect } = require("chai");
const { ethers } = require("hardhat");
require("@nomicfoundation/hardhat-chai-matchers");

describe("LoraDEX", function () {
    let LoraToken, LoraDEX, LoraFactory, LoraRouter;
    let loraToken, loraToken2, loraDEX, loraFactory, loraRouter;
    let owner, addr1, addr2, addr3, addrs;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
        
        // Deploy tokens
        LoraToken = await ethers.getContractFactory("LoraToken");
        loraToken = await LoraToken.deploy();
        await loraToken.waitForDeployment();
        await loraToken.setTransferCooldown(0);
        
        loraToken2 = await LoraToken.deploy();
        await loraToken2.waitForDeployment();
        await loraToken2.setTransferCooldown(0);
        
        // Deploy factory
        LoraFactory = await ethers.getContractFactory("LoraFactory");
        loraFactory = await LoraFactory.deploy(owner.address);
        await loraFactory.waitForDeployment();
        
        // Deploy router
        LoraRouter = await ethers.getContractFactory("LoraRouter");
        loraRouter = await LoraRouter.deploy(await loraFactory.getAddress(), ethers.ZeroAddress);
        await loraRouter.waitForDeployment();
        
        // Create pair
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
            const token1Address = await loraToken.getAddress();
            const token2Address = await loraToken2.getAddress();
            const dexTokenA = await loraDEX.tokenA();
            const dexTokenB = await loraDEX.tokenB();
            
            // Check that both tokens are present (order doesn't matter)
            expect([dexTokenA, dexTokenB]).to.include(token1Address);
            expect([dexTokenA, dexTokenB]).to.include(token2Address);
        });
    });

    describe("Liquidity", function () {
        it("Should add liquidity correctly", async function () {
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            // Approve DEX to spend tokens
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            // Transfer tokens to DEX before calling addLiquidity
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            
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
            
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, addr1.address, deadline);
            
            const liquidity = await loraDEX.balanceOf(addr1.address);
            
            // Then remove liquidity
            await loraDEX.connect(addr1).approve(await loraDEX.getAddress(), liquidity);
            await loraDEX.connect(addr1).removeLiquidity(liquidity, 0, 0, addr1.address, deadline);
            
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
            
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            
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
            const swapAmount = ethers.parseEther("10");
            
            // Transfer tokens to user
            await loraToken.transfer(addr1.address, swapAmount);
            
            // Transfer tokens to DEX before swap
            await loraToken.connect(addr1).transfer(await loraDEX.getAddress(), swapAmount);
            
            // Get reserves and calculate output
            const [reserveA, reserveB] = await loraDEX.getReserves();
            const amountOut = await loraDEX.getAmountOut(swapAmount, reserveA, reserveB);
            expect(amountOut).to.be.gt(0);
            
            // Identify which token is token0 and which is token1
            const tokenA = await loraDEX.tokenA();
            const tokenB = await loraDEX.tokenB();
            const loraTokenAddress = await loraToken.getAddress();
            const loraToken2Address = await loraToken2.getAddress();
            let amount0Out = 0, amount1Out = 0;
            if (tokenB === loraToken2Address) {
                // tokenB is token2, so amount1Out is the output
                amount1Out = amountOut;
            } else {
                // tokenA is token2, so amount0Out is the output
                amount0Out = amountOut;
            }
            
            // Get initial balance of output token (token2)
            const balanceBefore = await loraToken2.balanceOf(addr1.address);
            console.log("Token2 balance before:", balanceBefore.toString());
            
            // Perform swap
            await loraDEX.connect(addr1).swap(amount0Out, amount1Out, addr1.address, "0x");
            
            // Get final balance of output token (token2)
            const balanceAfter = await loraToken2.balanceOf(addr1.address);
            console.log("Token2 balance after:", balanceAfter.toString());
            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should fail swap with insufficient liquidity", async function () {
            const largeAmount = ethers.parseEther("50000"); // More than reserves
            
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
        it("should add liquidity through router", async function () {
            // Transfer tokens to user
            await loraToken.transfer(addr1.address, ethers.parseEther("1000"));
            await loraToken2.transfer(addr1.address, ethers.parseEther("1000"));
            
            // User approves router
            await loraToken.connect(addr1).approve(await loraRouter.getAddress(), ethers.parseEther("100"));
            await loraToken2.connect(addr1).approve(await loraRouter.getAddress(), ethers.parseEther("100"));
            
            // Add liquidity through router
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraRouter.connect(addr1).addLiquidity(
                await loraToken.getAddress(),
                await loraToken2.getAddress(),
                ethers.parseEther("100"),
                ethers.parseEther("100"),
                0,
                0,
                addr1.address,
                deadline
            );
            
            // Check LP token balance
            const lpBalance = await loraDEX.balanceOf(addr1.address);
            expect(lpBalance).to.be.gt(0);
        });

        it("should swap tokens through router", async function () {
            // First add liquidity
            const amountA = ethers.parseEther("1000");
            const amountB = ethers.parseEther("1000");
            
            await loraToken.approve(await loraDEX.getAddress(), amountA);
            await loraToken2.approve(await loraDEX.getAddress(), amountB);
            
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, owner.address, deadline);
            
            // Transfer tokens to user
            await loraToken.transfer(addr1.address, ethers.parseEther("100"));
            await loraToken2.transfer(addr1.address, ethers.parseEther("100"));
            
            // User approves router
            await loraToken.connect(addr1).approve(await loraRouter.getAddress(), ethers.parseEther("100"));
            await loraToken2.connect(addr1).approve(await loraRouter.getAddress(), ethers.parseEther("100"));
            
            // Get initial balances
            const initialBalanceA = await loraToken.balanceOf(addr1.address);
            const initialBalanceB = await loraToken2.balanceOf(addr1.address);
            
            // Approve router for swap
            await loraToken.connect(addr1).approve(await loraRouter.getAddress(), ethers.parseEther("10"));
            
            // Swap tokens
            const path = [await loraToken.getAddress(), await loraToken2.getAddress()];
            await loraRouter.connect(addr1).swapExactTokensForTokens(
                ethers.parseEther("10"),
                0,
                path,
                addr1.address,
                deadline
            );
            
            // Check balances changed
            const finalBalanceA = await loraToken.balanceOf(addr1.address);
            const finalBalanceB = await loraToken2.balanceOf(addr1.address);
            
            expect(finalBalanceA).to.be.lt(initialBalanceA);
            expect(finalBalanceB).to.be.gt(initialBalanceB);
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
            
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            
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
            await loraToken.transfer(await loraDEX.getAddress(), amountA);
            await loraToken2.transfer(await loraDEX.getAddress(), amountB);
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await loraDEX.addLiquidity(amountA, amountB, 0, 0, owner.address, deadline);
            
            // Then swap
            const swapAmount = ethers.parseEther("10");
            await loraToken.transfer(addr1.address, swapAmount);
            await loraToken.connect(addr1).transfer(await loraDEX.getAddress(), swapAmount);
            const reserves = await loraDEX.getReserves();
            const amountOut = await loraDEX.getAmountOut(swapAmount, reserves[0], reserves[1]);
            await expect(
                loraDEX.connect(addr1).swap(0, amountOut, addr1.address, "0x")
            ).to.emit(loraDEX, "Swap");
        });
    });
}); 