const hre = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const config = bridgeConfig[hre.network.name];
  const vaultConfig = bridgeConfig[vaultChain(hre.network.name)];

  const libraryNames = ["BeefyPendleStrategyLib"];

  const libraries = {};
  if (libraryNames !== undefined) {
    console.log('Found libraries to deploy and link!');
    for (const libraryName of libraryNames) {
      const library = await hre.ethers.deployContract(libraryName);
      console.log(`Deployed library: ${libraryName} - ${library.address}`);
      libraries[libraryName] = await library.getAddress();
      await hre.run("verify:verify", {
        address: await library.getAddress()
      });
    }
  } else {
    console.log("No external libraries for this strategy. Continue...");
  }

  let factoryParams;
  if (libraryNames.length > 0) {
    factoryParams = {
      libraries
    }
  }
  const BeefyPendleStrategy = await ethers.getContractFactory("BeefyPendleStrategy", factoryParams);

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
      unsafeAllow: [
        "external-library-linking"
      ]
    }
  );
  await beefyPendleStrategy.waitForDeployment();

  console.log("BeefyPendleStrategy deployed to:", await beefyPendleStrategy.getAddress());

  await hre.run("verify:verify", {
    address: await beefyPendleStrategy.getAddress(),
  });
};

module.exports.tags = ["BeefyPendleStrategyDeploy"];
