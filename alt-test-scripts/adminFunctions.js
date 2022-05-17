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
  const merch = await ethers.getContractFactory("SiblingsHoodies");
  [owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners();

  // To deploy our contract, we just have to call Token.deploy() and await
  // for it to be deployed(), which happens once its transaction has been
  // mined.
  Contract = await merch.deploy();
});

describe("Adding to the Allow List", function () {
  it("Activate sale, Add users to the allow list and only allow those users to mint", async function () {

    const activateSale = await Contract.activeSale()

    const setAllowList = await Contract.addAllowList([addr1.address, addr2.address, addr3.address]);

    expect(await Contract.allowList(addr1.address)).to.equal(true);
    expect(await Contract.allowList(addr2.address)).to.equal(true);
    expect(await Contract.allowList(addr3.address)).to.equal(true);
    expect(await Contract.allowList(addr4.address)).to.equal(false);
    expect(await Contract.allowList(addrs[1].address)).to.equal(false);

    await Contract.connect(addr1).mintToken();
    await Contract.connect(addr2).mintToken();
    await Contract.connect(addr3).mintToken();
    await expect(Contract.connect(addr4).mintToken()).to.be.reverted;
    await expect(Contract.connect(addrs[1]).mintToken()).to.be.reverted;

    expect(await Contract.balanceOf(addr1.address, 1)).to.equal(1);
    expect(await Contract.balanceOf(addr2.address, 1)).to.equal(1);
    expect(await Contract.balanceOf(addr3.address, 1)).to.equal(1);
    expect(await Contract.balanceOf(addr4.address, 1)).to.equal(0);
    expect(await Contract.balanceOf(addr5.address, 1)).to.equal(0);
  });

  it("Should activate the sale and set parameters", async function () {
    const activateSale = await Contract.activeSale()

    expect(await Contract.active()).to.equal(true);
    expect(await Contract.allowListOnly()).to.equal(true);
    expect(await Contract.phase()).to.equal(1);
  });

  it("Should change phases correctly", async function () {

  });
});
