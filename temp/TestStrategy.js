const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
    const TestStrategy = await ethers.getContractFactory("TestStrategy");
    const testStrategy = await upgrades.deployProxy(
        TestStrategy,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            vaultConfig.chainId,
            config.chainId,
            config.sgBridge,
            config.sgRouter,
            0,
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await testStrategy.deployed();

    console.log("TestStrategy deployed to:", testStrategy.address);

    await hre.run("verify:verify", {
        address: testStrategy.address,
    });
};

module.exports.tags = ["TestStrategy"];
