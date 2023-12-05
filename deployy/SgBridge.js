const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
async function main() {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const SgBridge = await ethers.getContractFactory("SgBridge");
  const sgBridge = await upgrades.deployProxy(
    SgBridge,
    [
      bridgeConfig[hre.network.name].sgRouter,
      bridgeConfig[hre.network.name].chainId,
    ],
    {
      initializer: "initialize",
      kind: "transparent",
    }
  );
  await sgBridge.deployed();

  console.log("SgBridge deployed to:", sgBridge.address);

  await hre.run("verify:verify", {
    address: sgBridge.address,
  });
}
main();
module.exports.tags = ["SgBridge"];
