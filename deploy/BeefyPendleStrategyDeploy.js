const hre = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];
  const BeefyPendleStrategy = await ethers.getContractFactory("BeefyPendleStrategy");
  const beefyPendleStrategy = await upgrades.deployProxy(
    BeefyPendleStrategy,
    [
      config.lzEndpoint,
      config.strategist,
      config.harvester,
      config[TOKEN].address,
      vaultConfig.vault,
      vaultConfig.chainId,
      config.chainId,
      config.sgBridge,
      config.sgRouter,
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await beefyPendleStrategy.waitForDeployment();

  console.log("BeefyPendleStrategy deployed to:", await beefyPendleStrategy.getAddress());

  await hre.run("verify:verify", {
    address: await beefyPendleStrategy.getAddress(),
  });
};

module.exports.tags = ["BeefyPendleStrategyDeploy"];
