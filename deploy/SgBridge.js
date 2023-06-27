const { ethers, upgrades } = require("hardhat");

const stargateRouters = require("../constants/stargateRouters.json");

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();
    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await upgrades.deployProxy(
        SgBridge,
        [stargateRouters[hre.network.name]],
        {
            initializer: "initialize",
        }
    );
    console.log("SgBridge deployed to:", sgBridge.address);
};

module.exports.tags = ["SgBridge"];
