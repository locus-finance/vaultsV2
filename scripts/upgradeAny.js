// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0xa5e7eB6391F34Ec9691A5d39E93A8b2336B7E717";
  const TARGET_STRATEGY = "VelodromeStrategy";
  //   console.log(1);
  // const provider = new hre.ethers.providers.JsonRpcProvider(
  //   "http://127.0.0.1:8545"
  // );
  // let wallet = await new ethers.Wallet(
  //   process.env.DEPLOYER_PRIVATE_KEY
  // ).connect(provider);
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
