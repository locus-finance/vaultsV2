// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0x0427eE06e5220BA8013d2A753109A57AD4020373";
  const TARGET_STRATEGY = "HopStrategy";
  //   console.log(1);
  const TargetContract = await hre.ethers.getContractFactory(TARGET_STRATEGY);

  const upgraded = await hre.upgrades.upgradeProxy(
    TARGET_ADDRESS,
    TargetContract
  );

  console.log("Successfully upgraded implementation of", upgraded.address);

  //   await hre.run("verify:verify", {
  //     address: upgraded.address,
  //   });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
