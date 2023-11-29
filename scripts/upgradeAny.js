// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0xf712eE1C45C84aEC0bfA1581f34B9dc9a54D7e60";
  const TARGET_STRATEGY = "Vault";
  //   console.log(1);
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
