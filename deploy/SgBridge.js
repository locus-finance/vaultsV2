const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");
async function main() {


  // const SgBridge = await ethers.getContractFactory("SgBridge");
  // const sgBridge = await upgrades.deployProxy(
  //   SgBridge,
  //   [
  //     bridgeConfig[hre.network.name].sgRouter,
  //     bridgeConfig[hre.network.name].chainId
  //   ],
  //   {
  //     initializer: "initialize",
  //     kind: "uups",
  //   }
  // );
  // await sgBridge.waitForDeployment();

  // console.log("SgBridge deployed to:", await sgBridge.getAddress());

  await hre.run("verify:verify", {
    address: "0x1B4C9A314117E037461FBdc980C9DeBeFEE6F891",
  });
}
main();
module.exports.tags = ["SgBridge"];
