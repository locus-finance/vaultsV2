const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();

    console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

    let swapHelper = await ethers.deployContract(
        "SwapHelper",
        
    );
    
    await swapHelper.waitForDeployment();

    console.log("SwapHelper deployed to:", swapHelper.target);

    await hre.run("verify:verify", {
        address: swapHelper.target,
    });
};

module.exports.tags = ["SwapHelper"];
