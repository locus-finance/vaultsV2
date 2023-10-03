const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
    const AeroStrategy = await ethers.getContractFactory("AeroStrategy");
    const aeroStrategy = await upgrades.deployProxy(
        AeroStrategy,
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
    await aeroStrategy.deployed();

    console.log("AeroStrategy deployed to:", aeroStrategy.address);

    await hre.run("verify:verify", {
        address: aeroStrategy.address,
    });
};

module.exports.tags = ["AeroStrategy"];
