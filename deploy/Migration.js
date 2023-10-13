const { ethers } = require("hardhat");

const migrationConfig = require("../constants/Migration.json");
module.exports = async function ({ getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);
  const config = migrationConfig["mainnet"];
  const Migration = await ethers.getContractFactory("Migration");
  const migration = await Migration.deploy(
    config.vaultV1,
    config.accounts,
    config.treasury
  );
  await migration.deployed();

  console.log("Migration deployed to:", migration.address);

  await hre.run("verify:verify", {
    address: migration.address,
  });
};

module.exports.tags = ["Migration"];
