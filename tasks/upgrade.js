module.exports = async function (taskArgs, hre) {
    await hre.run("compile");

    const { deployer } = await getNamedAccounts();
    const { targetContract, targetAddr } = taskArgs;
    const networkName = hre.network.name;

    console.log(`Your address: ${deployer}. Network: ${networkName}`);
    console.log(`Upgrading ${targetContract} at ${targetAddr}`);

    const TargetContract = await ethers.getContractFactory(targetContract);
    const upgraded = await hre.upgrades.upgradeProxy(
        targetAddr,
        TargetContract,
        {
            unsafeSkipStorageCheck: true,
        }
    );

    await hre.run("verify:verify", {
        address: upgraded.address,
    });
};