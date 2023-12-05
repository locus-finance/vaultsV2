const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

async function main() {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
  const VeloStrategy = await ethers.getContractFactory("VelodromeStrategy");
  const veloStrategy = await upgrades.deployProxy(
    VeloStrategy,
    [
      config.lzEndpoint,
      config.strategist,
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
  console.log(4);
  await veloStrategy.deployed();

  console.log("VeloStrategy deployed to:", veloStrategy.address);

  await hre.run("verify:verify", {
    address: veloStrategy.address,
  });
}
try {
  main();
} catch (error) {
  console.log(error);
}
module.exports.tags = ["VelodromeStrategy"];
