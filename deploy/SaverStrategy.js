const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  const networkName = hre.network.name; // abstraction for a debugging
  console.log(`Your address: ${deployer}. Network: ${networkName}`);
  const config = bridgeConfig[networkName];
  const vaultConfig = bridgeConfig[vaultChain(networkName)];

  const saver = "0x5C6412CE0E1f5C15C98AEbc5353d936Ed9bC5Bf1";
  const beefyCurveStrategyFactory = await ethers.getContractFactory("SaverStrategy");
  const beefyCurveStrategy = await upgrades.deployProxy(
    beefyCurveStrategyFactory,
    [
      saver,
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

  console.log("SaverStrategy deployed to:", beefyCurveStrategy.address);

  await hre.run("verify:verify", {
    address: beefyCurveStrategy.address,
  });

  console.log("Deploy scripts: SaverStrategy is verified and configured.");
};

module.exports.tags = ["SaverStrategy"];
