const { expect } = require("chai");
const { ethers } = require("hardhat");

let Contract;
let owner;
let addr1;
let addr2;
let addr3;
let addr4;
let addr5;
let addrs;

beforeEach(async function () {
  // Get the ContractFactory and Signers here.
  const merch = await ethers.getContractFactory("SiblingHoodies");
  [owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners();

  // To deploy our contract, we just have to call Token.deploy() and await
  // for it to be deployed(), which happens once its transaction has been
  // mined.
  Contract = await merch.deploy();
});

describe("Deployment", function() {
  it("Should not allow users to mint", async function () {
    await expect(Contract.mintToken()).to.be.reverted;
    await expect(Contract.connect(addr1).mintToken()).to.be.reverted;
  });

  it("Should not users to change parameters if not owner", async function () {
    await expect(Contract.connect(addr1).activeSale()).to.be.reverted;
    await expect(Contract.connect(addr1).activatePublicSale()).to.be.reverted;
    await expect(Contract.connect(addr1).activateNextPhase()).to.be.reverted;
    await expect(Contract.connect(addr1).addAllowList([addr1.address])).to.be.reverted;
    await expect(Contract.connect(addr1).updateUri(1, "")).to.be.reverted;
    await expect(Contract.connect(addr1).updateRoyalties(addr2.address, 1000)).to.be.reverted;
  });
});

