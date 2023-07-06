const { ethers } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    const config = bridgeConfig[hre.network.name];
    const Vault = await ethers.getContractFactory("Vault");
    const vault = await Vault.deploy(
        deployer,
        config.lzEndpoint,
        config[TOKEN].address,
        config.sgBridge,
        config.sgRouter
    );
    await vault.deployed();

    console.log("Vault deployed to:", vault.address);

    await hre.run("verify:verify", {
        address: vault.address,
        constructorArguments: [
            deployer,
            config.lzEndpoint,
            config[TOKEN].address,
            config.sgBridge,
            config.sgRouter,
        ],
    });
};

module.exports.tags = ["Vault"];
