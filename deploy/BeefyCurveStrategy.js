const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDT";

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    const networkName = hre.network.name; // abstraction for a debugging
    console.log(`Your address: ${deployer}. Network: ${networkName}`);
    const config = bridgeConfig[networkName];
    const vaultConfig = bridgeConfig[vaultChain(networkName)];
    
    const beefyCurveStrategyFactory = await ethers.getContractFactory("BeefyCurveStrategy");
    const beefyCurveStrategy = await upgrades.deployProxy(
        beefyCurveStrategyFactory,
        [
            config.lzEndpoint,
            deployer,
            config[TOKEN].address,
            vaultConfig.vault,
            config.chainId,
            vaultConfig.chainId,
            config.sgBridge,
            config.sgRouter
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await beefyCurveStrategy.deployed();
    
    console.log("BeefyCurveStrategy deployed to:", beefyCurveStrategy.address);
    
    await hre.run("verify:verify", {
        address: beefyCurveStrategy.address,
    });

    // WATCH OUT FOR HARD CODED SETTERS VALUES

    // const setManagementFeeTx = await beefyCurveStrategy.setManagementFee(7000);
    // await setManagementFeeTx.wait();

    // const setStrategistTx = await beefyCurveStrategy.setStrategist("0x27f52fd2E60B1153CBD00D465F97C05245D22B82");
    // await setStrategistTx.wait();
    
    // const setTreasuryAddressTx = await beefyCurveStrategy.setTreasuryAddress("0xf4bec3e032590347fc36ad40152c7155f8361d39");
    // await setTreasuryAddressTx.wait();

    // console.log("Deploy scripts: BeefyStrategy is verified and configured.");
};

module.exports.tags = ["BeefyCurveStrategy"];