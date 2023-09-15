const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

//!Form config

async function deployAeroStrategy() {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);
    const config = bridgeConfig["base"];
    const vaultConfig = bridgeConfig[vaultChain("base")];
    const Strategy = await ethers.getContractFactory("AeroStrategy");
    const strategy = await upgrades.deployProxy(
        Strategy,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            vaultConfig.chainId,
            config.sgBridge,
            config.sgRouter,
            config.slippage,
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await strategy.deployed();

    console.log("Aero strategy deployed to:", strategy.address);

    await hre.run("verify:verify", {
        address: strategy.address,
    });
}

module.exports.tags = ["AeroStrategy"];

deployAeroStrategy()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .then(() => { });
