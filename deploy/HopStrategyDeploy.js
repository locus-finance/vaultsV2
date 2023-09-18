const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
    const HopStrategy = await ethers.getContractFactory("HopStrategy");
    const hopStrategy = await upgrades.deployProxy(
        HopStrategy,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            vaultConfig.chainId,
            config.chainId,
            config.sgBridge,
            config.sgRouter,
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await hopStrategy.deployed();

    console.log("HopStrategy deployed to:", hopStrategy.address);

    await hre.run("verify:verify", {
        address: hopStrategy.address,
    });
};

module.exports.tags = ["HopStrategy"];
