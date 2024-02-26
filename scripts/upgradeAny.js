// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0x68Ee86f798f247FeC4d33C224Dad360dC919450A";
  const TARGET_STRATEGY = "HopStrategy";

  const TargetContract = await hre.ethers.getContractFactory(TARGET_STRATEGY);

  const upgraded = await hre.upgrades.upgradeProxy(
    TARGET_ADDRESS,
    TargetContract
  );

  console.log("Successfully upgraded implementation of", await upgraded.getAddress());

  await hre.run("verify:verify", {
    address:await upgraded.getAddress(),
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
