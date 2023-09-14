const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../../constants/bridgeConfig.json");
const { oppositeChain } = require("../../utils");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[oppositeChain(hre.network.name)];
  const PikaStrategy = await ethers.getContractFactory("PikaStrategy");
  const pikaStrategy = await upgrades.deployProxy(
    PikaStrategy,
    [
      config.lzEndpoint,
      deployer,
      config[TOKEN].address,
      vaultConfig.vault,
      vaultConfig.chainId,
      config.sgBridge,
      config.sgRouter,
    ],
    {
      initializer: "initialize",
      kind: "transparent",
    }
  );
  await pikaStrategy.deployed();

  console.log("TestStrategy deployed to:", pikaStrategy.address);

  await hre.run("verify:verify", {
    address: pikaStrategy.address,
  });
};

module.exports.tags = ["PikaStrategy"];
