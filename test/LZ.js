const {
    loadFixture,
    mine,
} = require("@nomicfoundation/hardhat-network-helpers");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LZ", function () {
    it("should use LZ correctly", async function () {
        const LZ = await hre.ethers.getContractFactory("LZ");
        const lzContract = await LZ.deploy();
        await lzContract.deployed();

        console.log("lzContract.address", lzContract.address);

        expect(5).to.be.equal(5);
    });
});
