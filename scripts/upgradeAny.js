// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0xC4E7d7c15b8F5c2D77512460b84802D1D3693692";
  const TARGET_STRATEGY = "BeefyCurveStrategy";

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
