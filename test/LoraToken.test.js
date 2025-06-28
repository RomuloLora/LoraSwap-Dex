const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoraToken", function () {
    let LoraToken;
    let loraToken;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        LoraToken = await ethers.getContractFactory("LoraToken");
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        loraToken = await LoraToken.deploy();
        await loraToken.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await loraToken.owner()).to.equal(owner.address);
        });

        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await loraToken.balanceOf(owner.address);
            expect(await loraToken.totalSupply()).to.equal(ownerBalance);
        });

        it("Should have correct initial supply", async function () {
            const expectedSupply = ethers.parseEther("1000000"); // 1 milhão
            expect(await loraToken.totalSupply()).to.equal(expectedSupply);
        });

        it("Should have correct name and symbol", async function () {
            expect(await loraToken.name()).to.equal("Lora Token");
            expect(await loraToken.symbol()).to.equal("LORA");
        });

        it("Should have 18 decimals", async function () {
            expect(await loraToken.decimals()).to.equal(18);
        });
    });

    describe("Minting", function () {
        it("Should allow owner to mint tokens", async function () {
            const mintAmount = ethers.parseEther("1000");
            await loraToken.mint(addr1.address, mintAmount);
            expect(await loraToken.balanceOf(addr1.address)).to.equal(mintAmount);
        });

        it("Should allow minter to mint tokens", async function () {
            await loraToken.addMinter(addr1.address);
            const mintAmount = ethers.parseEther("1000");
            await loraToken.connect(addr1).mint(addr2.address, mintAmount);
            expect(await loraToken.balanceOf(addr2.address)).to.equal(mintAmount);
        });

        it("Should not allow non-owner/non-minter to mint", async function () {
            const mintAmount = ethers.parseEther("1000");
            await expect(
                loraToken.connect(addr1).mint(addr2.address, mintAmount)
            ).to.be.revertedWith("Not authorized to mint");
        });

        it("Should not exceed max supply", async function () {
            const maxSupply = await loraToken.MAX_SUPPLY();
            const currentSupply = await loraToken.totalSupply();
            const remainingSupply = maxSupply - currentSupply;
            
            await loraToken.mint(addr1.address, remainingSupply);
            
            await expect(
                loraToken.mint(addr1.address, ethers.parseEther("1"))
            ).to.be.revertedWith("Would exceed max supply");
        });
    });

    describe("Minter Management", function () {
        it("Should allow owner to add minter", async function () {
            await loraToken.addMinter(addr1.address);
            expect(await loraToken.isMinter(addr1.address)).to.be.true;
        });

        it("Should allow owner to remove minter", async function () {
            await loraToken.addMinter(addr1.address);
            await loraToken.removeMinter(addr1.address);
            expect(await loraToken.isMinter(addr1.address)).to.be.false;
        });

        it("Should not allow non-owner to add minter", async function () {
            await expect(
                loraToken.connect(addr1).addMinter(addr2.address)
            ).to.be.revertedWithCustomError(loraToken, "OwnableUnauthorizedAccount");
        });

        it("Should not allow non-owner to remove minter", async function () {
            await loraToken.addMinter(addr1.address);
            await expect(
                loraToken.connect(addr2).removeMinter(addr1.address)
            ).to.be.revertedWithCustomError(loraToken, "OwnableUnauthorizedAccount");
        });

        it("Should not allow adding zero address as minter", async function () {
            await expect(
                loraToken.addMinter(ethers.ZeroAddress)
            ).to.be.revertedWith("Invalid minter address");
        });
    });

    describe("Transfers", function () {
        it("Should transfer tokens between accounts", async function () {
            const transferAmount = ethers.parseEther("100");
            await loraToken.transfer(addr1.address, transferAmount);
            expect(await loraToken.balanceOf(addr1.address)).to.equal(transferAmount);
        });

        it("Should fail if sender doesn't have enough tokens", async function () {
            const initialOwnerBalance = await loraToken.balanceOf(owner.address);
            await expect(
                loraToken.connect(addr1).transfer(owner.address, ethers.parseEther("1"))
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
            expect(await loraToken.balanceOf(owner.address)).to.equal(initialOwnerBalance);
        });

        it("Should respect transfer cooldown", async function () {
            const transferAmount = ethers.parseEther("100");
            await loraToken.transfer(addr1.address, transferAmount);
            
            // Tentar transferir novamente imediatamente deve falhar
            await expect(
                loraToken.transfer(addr2.address, transferAmount)
            ).to.be.revertedWith("Transfer cooldown active");
        });

        it("Should allow transfer after cooldown", async function () {
            const transferAmount = ethers.parseEther("100");
            await loraToken.transfer(addr1.address, transferAmount);
            
            // Avançar o tempo
            await ethers.provider.send("evm_increaseTime", [3600]); // 1 hora
            await ethers.provider.send("evm_mine");
            
            // Agora deve funcionar
            await loraToken.transfer(addr2.address, transferAmount);
            expect(await loraToken.balanceOf(addr2.address)).to.equal(transferAmount);
        });
    });

    describe("Approvals", function () {
        it("Should approve tokens for delegated transfer", async function () {
            const approveAmount = ethers.parseEther("100");
            await loraToken.approve(addr1.address, approveAmount);
            expect(await loraToken.allowance(owner.address, addr1.address)).to.equal(approveAmount);
        });

        it("Should transfer tokens using transferFrom", async function () {
            const approveAmount = ethers.parseEther("100");
            const transferAmount = ethers.parseEther("50");
            
            await loraToken.approve(addr1.address, approveAmount);
            await loraToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount);
            
            expect(await loraToken.balanceOf(addr2.address)).to.equal(transferAmount);
            expect(await loraToken.allowance(owner.address, addr1.address)).to.equal(approveAmount - transferAmount);
        });

        it("Should fail transferFrom if not enough allowance", async function () {
            const approveAmount = ethers.parseEther("100");
            const transferAmount = ethers.parseEther("150");
            
            await loraToken.approve(addr1.address, approveAmount);
            await expect(
                loraToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount)
            ).to.be.revertedWith("ERC20: insufficient allowance");
        });
    });

    describe("Pausing", function () {
        it("Should allow owner to pause and unpause", async function () {
            await loraToken.pause();
            expect(await loraToken.paused()).to.be.true;
            
            await loraToken.unpause();
            expect(await loraToken.paused()).to.be.false;
        });

        it("Should not allow transfers when paused", async function () {
            await loraToken.pause();
            await expect(
                loraToken.transfer(addr1.address, ethers.parseEther("100"))
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Should not allow non-owner to pause", async function () {
            await expect(
                loraToken.connect(addr1).pause()
            ).to.be.revertedWithCustomError(loraToken, "OwnableUnauthorizedAccount");
        });
    });

    describe("Cooldown Management", function () {
        it("Should allow owner to update transfer cooldown", async function () {
            const newCooldown = 7200; // 2 horas
            await loraToken.setTransferCooldown(newCooldown);
            expect(await loraToken.transferCooldown()).to.equal(newCooldown);
        });

        it("Should not allow non-owner to update cooldown", async function () {
            await expect(
                loraToken.connect(addr1).setTransferCooldown(7200)
            ).to.be.revertedWithCustomError(loraToken, "OwnableUnauthorizedAccount");
        });
    });

    describe("Burning", function () {
        it("Should allow burning tokens", async function () {
            const burnAmount = ethers.parseEther("1000");
            const initialSupply = await loraToken.totalSupply();
            
            await loraToken.burn(burnAmount);
            
            expect(await loraToken.totalSupply()).to.equal(initialSupply - burnAmount);
        });

        it("Should not allow burning more than balance", async function () {
            const burnAmount = ethers.parseEther("2000000"); // Mais que o supply inicial
            await expect(
                loraToken.burn(burnAmount)
            ).to.be.revertedWith("ERC20: burn amount exceeds balance");
        });
    });
}); 