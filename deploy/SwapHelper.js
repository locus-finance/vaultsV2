const hre = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy(
        "SwapHelper",
        {
            from: deployer, 
            log: true, 
            skipIfAlreadyDeployed: true,
            args: [
                140,
                1100,
                deployer,
                "0x1111111254EEB25477B68fb85Ed929f73A960582",
                "0x514910771AF9Ca656af840dff83E8264EcF986CA",
                "0x0168B5FcB54F662998B0620b9365Ae027192621f",
                "e11192612ceb48108b4f2730a9ddbea3",
                "0eb8d4b227f7486580b6f66706ac5d47",
                [deployer]
            ]
        }
    );

    if (hre.network === "mainnet") {
        await hre.run("verify:verify", {
            address: swapHelper.target,
        });
    }
};

module.exports.tags = ["SwapHelper"];
