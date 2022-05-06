const { expect } = require("chai");
const { ethers } = require("hardhat");

beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    var contract = await ethers.getContractFactory("SibHoodies");
    const sibHoodiesContract = await contract.deploy();

    contract = await ethers.getContractFactory("TestToken");
    const testToken = await contract.deploy();
});

describe("");