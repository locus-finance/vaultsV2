const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";
async function main() {
  

  // console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);
  const config = bridgeConfig["arbitrumOne"];
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await upgrades.deployProxy(
    Vault,
    [
      config.governance,
      config.mainAdmin,
      config.lzEndpoint,
      config[TOKEN].address,
      config.sgRouter,
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await vault.waitForDeployment();

  console.log("Vault deployed to:", await vault.getAddress());

  await hre.run("verify:verify", {
    address: await vault.getAddress(),
  });
}
main();

module.exports.tags = ["Vault"];
