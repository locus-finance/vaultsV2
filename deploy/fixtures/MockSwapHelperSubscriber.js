const hre = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy(
        "MockSwapHelperSubscriber",
        {
            from: deployer, 
            log: true, 
            skipIfAlreadyDeployed: true
        }
    );
};

module.exports.tags = ["MockSwapHelperSubscriber"];
