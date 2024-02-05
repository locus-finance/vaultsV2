// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0xA93e1DfF89dcCCA3C3CadFd0A28aD071C230eD84";
  const TARGET_STRATEGY = "HopStrategy";

  const TargetContract = await hre.ethers.getContractFactory(TARGET_STRATEGY);

  const upgraded = await hre.upgrades.upgradeProxy(
    TARGET_ADDRESS,
    TargetContract
  );

  console.log("Successfully upgraded implementation of", upgraded.address);

  await hre.run("verify:verify", {
    address: upgraded.address,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
