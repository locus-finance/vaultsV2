const { ethers, upgrades } = require("hardhat");

const bridgeConfig = require("../constants/bridgeConfig.json");

module.exports = async function ({ getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);
  console.log(hre.network.name);
  const SgBridge = await ethers.getContractFactory("SgBridge");
  const sgBridge = await upgrades.deployProxy(
    SgBridge,
    [bridgeConfig[hre.network.name].sgRouter],
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
};

module.exports.tags = ["SgBridge"];
