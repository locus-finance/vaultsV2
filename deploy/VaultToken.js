const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";
async function main() {

  const config = bridgeConfig["arbitrumOne"];
  const Vault = await ethers.getContractFactory("VaultToken");
  const vault = await upgrades.deployProxy(
    Vault,
    [config.strategist, config.vault],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await vault.waitForDeployment();

  console.log("Token deployed to:", await vault.getAddress());

  await hre.run("verify:verify", {
    address: await vault.getAddress(),
  });
}
main();

module.exports.tags = ["Vault"];
