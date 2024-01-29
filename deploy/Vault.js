const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";
async function main() {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);
  // const config = bridgeConfig["arbitrumOne"];
  // const Vault = await ethers.getContractFactory("Vault");
  // const vault = await upgrades.deployProxy(
  //   Vault,
  //   [
  //     config.governance,
  //     config.lzEndpoint,
  //     config[TOKEN].address,
  //     config.sgRouter,
  //   ],
  //   {
  //     initializer: "initialize",
  //     kind: "transparent",
  //   }
  // );
  // await vault.deployed();

  // console.log("Vault deployed to:", vault.address);

  await hre.run("verify:verify", {
    address: "0x2a889E9ef10c7Bd607473Aadc8c806c4511EB26f",
  });
}
main();

module.exports.tags = ["Vault"];
