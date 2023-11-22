const hre = require("hardhat");

async function main() {
  const TARGET_ADDRESS = "0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3";// "0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3"; // 0x13bf88e6d5105f7935C0A8F88d7e87716e9Bb535
  const TARGET_STRATEGY = "BeefyStrategy";

  const TargetContract = await hre.ethers.getContractFactory(TARGET_STRATEGY);

  // await hre.upgrades.forceImport(TARGET_ADDRESS, TargetContract);

  const upgraded = await hre.upgrades.upgradeProxy(
    TARGET_ADDRESS,
    TargetContract
  );

  console.log("Successfully upgraded implementation of", upgraded.address);

  // const strategyInstance = await hre.ethers.getContractAt(
  //   TARGET_STRATEGY,
  //   TARGET_ADDRESS
  // );

  // const setManagementFeeTx = await strategyInstance.setManagementFee(7000);
  // await setManagementFeeTx.wait();

  // const setStrategistTx = await strategyInstance.setStrategist("0x27f52fd2E60B1153CBD00D465F97C05245D22B82");
  // await setStrategistTx.wait();
  
  // const setTreasuryAddressTx = await strategyInstance.setTreasuryAddress("0xf4bec3e032590347fc36ad40152c7155f8361d39");
  // await setTreasuryAddressTx.wait();

  // const setVaultTx = await strategyInstance.setVault("0xf712eE1C45C84aEC0bfA1581f34B9dc9a54D7e60", 110);
  // await setVaultTx.wait();

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
