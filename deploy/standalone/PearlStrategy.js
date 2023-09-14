const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../../constants/bridgeConfig.json");
const { vaultChain } = require("../../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
  const PearlStrategy = await ethers.getContractFactory("PearlStrategy");
  const pearlStrategy = await upgrades.deployProxy(
    PearlStrategy,
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
  await pearlStrategy.deployed();

  console.log("PearlStrategy deployed to:", pearlStrategy.address);

  await hre.run("verify:verify", {
    address: pearlStrategy.address,
  });
};

module.exports.tags = ["PearlStrategy"];
