const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { oppositeChain } = require("../utils");

const TOKEN = "USDCe";

//!Form config

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const vaultConfig = bridgeConfig[oppositeChain(hre.network.name)];
    const HopStrategy = await ethers.getContractFactory("HopStrategy");
    const hopStrategy = await upgrades.deployProxy(
        HopStrategy,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            vaultConfig.chainId,
            config.sgBridge,
            config.sgRouter,
            config.slippage
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await hopStrategy.deployed();

    console.log("hopStrategy deployed to:", hopStrategy.address);

    await hre.run("verify:verify", {
        address: hopStrategy.address,
    });
};

module.exports.tags = ["HopStrategy"];
