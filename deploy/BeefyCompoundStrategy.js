const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";
async function main() {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
  const BeefyCompoundStrategy = await ethers.getContractFactory(
    "BeefyCompoundStrategy"
  );
  const beefyCompoundStrategy = await upgrades.deployProxy(
    BeefyCompoundStrategy,
    [
      config.lzEndpoint,
      config.strategist,
      config[TOKEN].address,
      vaultConfig.vault,
      vaultConfig.chainId,
      config.chainId,
      config.sgBridge,
      config.sgRouter,
      hre.network.name,
    ],
    {
      initializer: "initialize",
      kind: "transparent",
    }
  );
  await beefyCompoundStrategy.deployed();

  console.log(
    "BeefyCompoundStrategy deployed to:",
    beefyCompoundStrategy.address
  );

  await hre.run("verify:verify", {
    address: beefyCompoundStrategy.address,
  });
}
main();

module.exports.tags = ["BeefyCompoundStrategy"];
