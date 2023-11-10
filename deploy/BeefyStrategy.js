const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDbC"; // CHANGE IF YOU WANT TO RE\DEPLOY ON ANOTHER NETWORK

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    const networkName = hre.network.name; // abstraction for a debugging
    console.log(`Your address: ${deployer}. Network: ${networkName}`);
    const config = bridgeConfig[networkName];
    const vaultConfig = bridgeConfig[vaultChain(networkName)];
    
    const beefyStrategyFactory = await ethers.getContractFactory("BeefyStrategy");
    const beefyStrategy = await upgrades.deployProxy(
        beefyStrategyFactory,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            config.chainId,
            vaultConfig.chainId,
            config.sgBridge,
            config.sgRouter,
            networkName
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

    // WATCH OUT FOR HARD CODED SETTERS VALUES

    const setManagementFeeTx = await beefyStrategy.setManagementFee(7000);
    await setManagementFeeTx.wait();

    const setStrategistTx = await beefyStrategy.setStrategist("0x27f52fd2E60B1153CBD00D465F97C05245D22B82");
    await setStrategistTx.wait();
    
    const setTreasuryAddressTx = await beefyStrategy.setTreasuryAddress("0xf4bec3e032590347fc36ad40152c7155f8361d39");
    await setTreasuryAddressTx.wait();

    console.log("Deploy scripts: BeefyStrategy is verified and configured.");
};

module.exports.tags = ["beefy"];
