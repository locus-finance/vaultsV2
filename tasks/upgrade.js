module.exports = async function (taskArgs, hre) {
  await hre.run("compile");

  const { deployer } = await getNamedAccounts();
  const { targetContract, targetAddr } = taskArgs;
  const networkName = hre.network.name;

  console.log(`Your address: ${deployer}. Network: ${networkName}`);
  console.log(`Upgrading ${targetContract} at ${targetAddr}`);
  const adminAddr = await hre.upgrades.erc1967.getAdminAddress(targetAddr);
  console.log("Admin address: " + adminAddr);
  const TargetContract = await ethers.getContractFactory(
    targetContract,
    deployer
  );
  const upgraded = await hre.upgrades.upgradeProxy(targetAddr, TargetContract);

  await hre.run("verify:verify", {
    address: upgraded.address,
  });
};
