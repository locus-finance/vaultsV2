const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
const { vaultChain } = require("../utils");

const TOKEN = "USDC";
async function main() {


  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
  const BeefyCompoundStrategy = await ethers.getContractFactory(
    "SaverStrategy"
  );
  const beefyCompoundStrategy = await upgrades.deployProxy(
    BeefyCompoundStrategy,
    [
      config.lzEndpoint,
      config.strategist,
      config.harvester,
      config[TOKEN].address,
      vaultConfig.vault,
      vaultConfig.chainId,
      config.chainId,
      config.sgBridge,
      config.sgRouter
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await beefyCompoundStrategy.waitForDeployment();

  console.log(
    "Saver deployed to:",
   await beefyCompoundStrategy.getAddress()
  );

  await hre.run("verify:verify", {
    address: await beefyCompoundStrategy.getAddress(),
  });
}
main();

module.exports.tags = ["BeefyCompoundStrategy"];
