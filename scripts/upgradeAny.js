// const hre = require("hardhat");
const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0x6c090e79A9399c0003A310E219b2D5ed4E6b0428";
  const TARGET_STRATEGY = "Vault";
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

  const setSwapChannelTx = await upgraded.setSwapChannel("0xc5Dad0c33889693913617CEE718eE147bA61B4DC");
  await setSwapChannelTx.wait();
  console.log(`SwapChannel is set:\n${JSON.stringify(setSwapChannelTx)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
