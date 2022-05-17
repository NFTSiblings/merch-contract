const { expect } = require("chai");
const { ethers } = require("hardhat");

beforeEach(async function () {
    contract = await ethers.getContractFactory("SibHoodies");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    moreWallets = [];
    for (var i = 0; i < 100; i++) {
        wallet = ethers.Wallet.createRandom();
        moreWallets.push(wallet);
    }

    contractInstance = await contract.deploy();

    contract = await ethers.getContractFactory("TestToken");
    [owner, addr1, addr2] = await ethers.getSigners();
    testToken = await contract.deploy();

    const initERC20Balance = ethers.BigNumber.from("100000000000000000000");
    await testToken.mint(addr1.address, initERC20Balance);
    await testToken.mint(addr2.address, initERC20Balance);
    await testToken.connect(addr1).approve(contractInstance.address, initERC20Balance);
    await testToken.connect(addr2).approve(contractInstance.address, initERC20Balance);

    await contractInstance.setAshAddress(testToken.address);
});

describe("Deployment", function () {
    it("Payout Address is set to contract owner's wallet address", async function () {
        // THIS TEST REQUIRES THAT {payoutAddress} BE A PUBLIC VARIABLE ON THE SMART CONTRACT
        expect(await contractInstance.payoutAddress()).to.equal(owner.address);
    });
});

describe("Minting", function () {
    describe("During Allowlist Sale", function () {
        it("Caller must be on allowlist", async function () {
            await contractInstance.setSaleActive(true);
    
            await expect(contractInstance.connect(addr1).mint(true)).to.be.revertedWith("You must be on the allowlist to mint now");
    
            await contractInstance.addToAllowlist([addr1.address]);
    
            await contractInstance.connect(addr1).mint(true);
        });

        it("Mint function correctly mints token", async function () {
            await contractInstance.addToAllowlist([addr1.address]);
            await contractInstance.setSaleActive(true);
            await contractInstance.connect(addr1).mint(true);
    
            expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(1);
        });

        it("Accepts only the correct amount of ETH (when paying with ETH)", async function () {
            await contractInstance.addToAllowlist([addr1.address]);
            await contractInstance.setSaleActive(true);

            await expect(contractInstance.connect(addr1).mint(false))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await expect(contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("0.03") }))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await expect(contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("1") }))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("0.01") });
        });
    
        it("Transfers the correct amount of ASH (when paying with ASH)", async function () {
            await contractInstance.addToAllowlist([addr1.address]);
            await contractInstance.setSaleActive(true);
            const senderPriorBalance = await testToken.balanceOf(addr1.address);
            const payeePriorBalance = await testToken.balanceOf(await contractInstance.payoutAddress());
            await contractInstance.connect(addr1).mint(true);
            
            const senderExpectedBalance = senderPriorBalance - await contractInstance.ASH_PRICE_AL();
            expect(await testToken.balanceOf(addr1.address))
            .to.equal(ethers.BigNumber.from(senderExpectedBalance.toString()));

            const payeeExpectedBalance = payeePriorBalance + await contractInstance.ASH_PRICE_AL();
            expect(await testToken.balanceOf(await contractInstance.payoutAddress()))
            .to.equal(ethers.BigNumber.from(payeeExpectedBalance.toString()));
        });
    });

    describe("During Public Sale", function () {
        it("Mint function correctly mints token", async function () {
            await contractInstance.setAlRequirement(false);
            await contractInstance.setSaleActive(true);
            await contractInstance.connect(addr1).mint(true);
    
            expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(1);
        });

        it("Accepts only the correct amount of ETH (when paying with ETH)", async function () {
            await contractInstance.setAlRequirement(false);
            await contractInstance.setSaleActive(true);

            await expect(contractInstance.connect(addr1).mint(false))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await expect(contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("0.01") }))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await expect(contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("1") }))
            .to.be.revertedWith("Incorrect amount of Ether sent");

            await contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("0.03") });
        });
    
        it("Transfers the correct amount of ASH (when paying with ASH)", async function () {
            await contractInstance.setAlRequirement(false);
            await contractInstance.setSaleActive(true);
            const senderPriorBalance = await testToken.balanceOf(addr1.address);
            const payeePriorBalance = await testToken.balanceOf(await contractInstance.payoutAddress());
            await contractInstance.connect(addr1).mint(true);
            
            const senderExpectedBalance = senderPriorBalance - await contractInstance.ASH_PRICE();
            expect(await testToken.balanceOf(addr1.address))
            .to.equal(ethers.BigNumber.from(senderExpectedBalance.toString()));

            const payeeExpectedBalance = payeePriorBalance + await contractInstance.ASH_PRICE();
            expect(await testToken.balanceOf(await contractInstance.payoutAddress()))
            .to.equal(ethers.BigNumber.from(payeeExpectedBalance.toString()));
        });
    });

    it("Minting is not available until sale is activated", async function () {
        await contractInstance.addToAllowlist([addr1.address]);
        await expect(contractInstance.connect(addr1).mint(true)).to.be.revertedWith("Mint is not available now");

        await contractInstance.setSaleActive(true);

        await contractInstance.connect(addr1).mint(true);
    });

    it("No more than 100 can be minted", async function () {
        await contractInstance.addToAllowlist([addr1.address, addr2.address]);
        await contractInstance.setSaleActive(true);

        for (var i = 0; i < 99; i++) {
            await contractInstance.airdrop([moreWallets[i].address], 1);
        }

        // Checking that 100 tokens were actually minted
        expect(await contractInstance.balanceOf(moreWallets[98].address, 1)).to.equal(1);

        await contractInstance.connect(addr1).mint(true);

        await expect(contractInstance.connect(addr2).mint(true)).to.be.revertedWith("All tokens have been minted");
    });

    it("Wallets cannot mint more than one each", async function () {
        await contractInstance.addToAllowlist([addr1.address]);
        await contractInstance.setSaleActive(true);

        await contractInstance.connect(addr1).mint(true);
        await expect(contractInstance.connect(addr1).mint(true)).to.be.revertedWith("You have already minted");
    });

    it("Mint function still works when tokenLocked is true", async function () {
        await contractInstance.addToAllowlist([addr1.address]);
        await contractInstance.setSaleActive(true);
        await contractInstance.setTokenLock(true);
        await contractInstance.connect(addr1).mint(true);
    });

    it("Cannot mint when contract is paused", async function () {
        await contractInstance.addToAllowlist([addr1.address]);
        await contractInstance.setSaleActive(true);
        await contractInstance.togglePause();
        expect(await contractInstance.paused()).to.equal(true);
        await expect(contractInstance.connect(addr1).mint(true)).to.be.revertedWith("AdminPausable: contract is paused");
    });

    it("Mint still works if prices are set to 0", async function () {
        await contractInstance.addToAllowlist([addr1.address, addr2.address]);
        await contractInstance.setSaleActive(true);
        await contractInstance.setPrices([0,0,0,0]);

        await contractInstance.connect(addr1).mint(true);
        await contractInstance.connect(addr2).mint(false);
    });
});

describe("Redeeming", function () {
    it("Redemption unavailable if tokenRedeemable is false", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.setTokenRedeemable(false);

        await expect(contractInstance.connect(addr1).redeem(1)).to.be.revertedWith("Merch redemption is not available now");
    });

    it("Data validation for amount argument", async function () {
        await contractInstance.airdrop([addr1.address], 1);

        await expect(contractInstance.connect(addr1).redeem(0)).to.be.revertedWith("Cannot redeem less than one");

        await expect(contractInstance.connect(addr1).redeem(2)).to.be.revertedWith("ERC1155: burn amount exceeds balance");
    });

    it("Redemption burns and mints correct amount of tokens", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.airdrop([addr1.address], 1);

        await contractInstance.connect(addr1).redeem(2);

        expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(0);
        expect(await contractInstance.balanceOf(addr1.address, 2)).to.equal(2);
    });

    it("Redemption still works when tokenLocked is true", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.setTokenRedeemable(true);
        await contractInstance.setTokenLock(true);

        await contractInstance.connect(addr1).redeem(1);

        expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(0);
        expect(await contractInstance.balanceOf(addr1.address, 2)).to.equal(1);
    });

    it("Redemption is unavailable when contract is paused", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.setTokenRedeemable(true);
        await contractInstance.togglePause();

        await expect(contractInstance.connect(addr1).redeem(1)).to.be.revertedWith("AdminPausable: contract is paused");
    });
});

describe("Airdropping", function () {
    it("Airdrop function is only callable by admins", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await expect(contractInstance.connect(addr1).airdrop([addr1.address], 1))
        .to.be.revertedWith("AdminPrivileges: caller is not an admin");
    });

    it("Only tokenId 1 or 2 can be airdropped", async function () {
        await expect(contractInstance.airdrop([addr1.address], 0)).to.be.reverted;
        await expect(contractInstance.airdrop([addr1.address], 3)).to.be.reverted;
    });

    it("Airdrop function still works when tokenLocked is true", async function () {
        await contractInstance.setTokenLock(true);

        await contractInstance.airdrop([addr1.address], 1);
    });

    it("Airdrop function mints correct tokens to correct wallets", async function () {
        await contractInstance.airdrop([addr1.address, addr2.address], 1);
        expect (await contractInstance.balanceOf(addr1.address, 1)).to.equal(1);
        expect (await contractInstance.balanceOf(addr2.address, 1)).to.equal(1);
    });

    it("Airdrop still works when contract is paused", async function () {
        await contractInstance.togglePause();
        await contractInstance.airdrop([addr1.address], 1);
        expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(1);
    });
});

describe("Setter Functions", function () {
    it("setSaleActive", async function () {
        await contractInstance.setSaleActive(true);
        expect(await contractInstance.saleActive()).to.equal(true);
    });

    it("setPrices", async function () {
        const argArray = [
            ethers.BigNumber.from("11000000000000000000"),
            ethers.BigNumber.from("12000000000000000000"),
            ethers.BigNumber.from("130000000000000000"),
            ethers.BigNumber.from("140000000000000000")
        ];
        await contractInstance.setPrices(argArray);

        expect(await contractInstance.ASH_PRICE()).to.equal("11000000000000000000");
        expect(await contractInstance.ASH_PRICE_AL()).to.equal("12000000000000000000");
        expect(await contractInstance.ETH_PRICE()).to.equal(ethers.utils.parseEther("0.13"));
        expect(await contractInstance.ETH_PRICE_AL()).to.equal(ethers.utils.parseEther("0.14"));
    });

    it("setPayoutAddress", async function () {
        await contractInstance.setPayoutAddress(addr1.address);
        expect(await contractInstance.payoutAddress()).to.equal(addr1.address);
    });

    it("setTokenRedeemable", async function () {
        await contractInstance.setTokenRedeemable(true);
        expect(await contractInstance.tokenRedeemable()).to.equal(true);
    });

    it("setTokenLock", async function () {
        await contractInstance.setTokenLock(true);
        expect(await contractInstance.tokenLocked()).to.equal(true);
    });

    it("setURI", async function () {
        await contractInstance.setURI(1, "new uri");
        expect(await contractInstance.uri(1)).to.equal("new uri");
    });
});

describe("Transfers", function () {
    describe("Batch Transfer", function () {

        it("Tokens must not be locked", async function () {
            for (i = 0; i < 5; i++) {
                await contractInstance.airdrop([addr1.address], 1);
            }
            await contractInstance.setTokenLock(true);

            await expect(contractInstance.connect(addr1).safeBatchTransferFrom(addr1.address, addr2.address, [1], [5], []))
            .to.be.revertedWith("This token may not be transferred now");
        });

        it("Only tokenId 1 can be transferred", async function () {
            for (i = 0; i < 5; i++) {
                await contractInstance.airdrop([addr1.address], 2);
            }
            
            await expect(contractInstance.connect(addr1).safeBatchTransferFrom(addr1.address, addr2.address, [2], [5], []))
            .to.be.revertedWith("This token may not be transferred");
        });

    });
    
    describe("Single Transfer", function () {

        it("Tokens must not be locked", async function () {
            await contractInstance.airdrop([addr1.address], 1);
            await contractInstance.setTokenLock(true);

            await expect(contractInstance.connect(addr1).safeTransferFrom(addr1.address, addr2.address, 1, 1, []))
            .to.be.revertedWith("This token may not be transferred now");
        });

        it("Only tokenId 1 can be transferred", async function () {
            await contractInstance.airdrop([addr1.address], 2);
            
            await expect(contractInstance.connect(addr1).safeTransferFrom(addr1.address, addr2.address, 2, 1, []))
            .to.be.revertedWith("This token may not be transferred");
        });

    });

    it("Transfer must work correctly", async function () {

        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.connect(addr1).safeTransferFrom(addr1.address, addr2.address, 1, 1, []);

        expect(await contractInstance.balanceOf(addr1.address, 1)).to.equal(0);
        expect(await contractInstance.balanceOf(addr2.address, 1)).to.equal(1);

    });

    it("Caller must own enough tokens", async function () {

        await expect(contractInstance.connect(addr1).safeTransferFrom(addr1.address, addr2.address, 1, 1, []))
        .to.be.reverted;

    });

    it("Transfer is not available while contract is paused", async function () {
        await contractInstance.airdrop([addr1.address], 1);
        await contractInstance.togglePause();

        await expect(contractInstance.connect(addr1).safeTransferFrom(addr1.address, addr2.address, 1, 1, []))
        .to.be.revertedWith("AdminPausable: contract is paused");

    });
});

describe("Withdrawing funds from contract", function () {
    it("Withdraw function sends funds to the correct address", async function () {
        await contractInstance.addToAllowlist([addr1.address]);
        await contractInstance.setSaleActive(true);
        await contractInstance.connect(addr1).mint(false, { value: ethers.utils.parseEther("0.01")});
        
        const balancePrior = await ethers.provider.getBalance(owner.address);
        await contractInstance.withdraw();
        expect(await ethers.provider.getBalance(owner.address)).to.be.gt(balancePrior);
        expect(await ethers.provider.getBalance(contractInstance.address)).to.equal(0);
    });

    it("Only callable by admins", async function () {
        await expect(
            contractInstance.connect(addr1).withdraw()
        ).to.be.revertedWith("AdminPrivileges: caller is not an admin");
    });
});