const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { oppositeChain } = require("../utils");

const TOKEN = "USDCe";

//!Form config

async function deployHopStrategy() {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig["arbitrum"];
  // const vaultConfig = bridgeConfig[oppositeChain(hre.network.name)];
  const HopStrategy = await ethers.getContractFactory("HopStrategy");
  const hopStrategy = await upgrades.deployProxy(
    HopStrategy,
    [
      config.lzEndpoint,
      deployer,
      config[TOKEN].address,
      config.vault,
      config.vaultChainId,
      config.sgBridge,
      config.sgRouter,
      config.slippage,
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
}

module.exports.tags = ["HopStrategy"];

deployHopStrategy()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {});
