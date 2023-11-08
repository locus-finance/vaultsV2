const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDT";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
    const beefyStrategyFactory = await ethers.getContractFactory("BeefyStrategy");
    const beefyStrategy = await upgrades.deployProxy(
        beefyStrategyFactory,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            vaultConfig.chainId,
            config.sgBridge,
            config.sgRouter,
            hre.network.name
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await beefyStrategy.deployed();

    console.log("BeefyStrategy deployed to:", beefyStrategy.address);

    await hre.run("verify:verify", {
        address: beefyStrategy.address,
    });
};

module.exports.tags = ["BeefyStrategy"];
