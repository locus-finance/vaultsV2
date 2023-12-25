const hre = require("hardhat");

// SOME EXPLANATION: SwapChannel is a contract that swaps different token sent from SgBridge to
// a vault to vaults want token.
module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy(
        "SwapChannel",
        {
            from: deployer, 
            log: true, 
            skipIfAlreadyDeployed: true,
            args: [
                '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
                '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8',
                '0xE592427A0AEce92De3Edee1F18E0157C05861564',
                '0x6c090e79A9399c0003A310E219b2D5ed4E6b0428',
                9800,
                500
            ]
        }
    );

    if (hre.network === "arbitrumOne") {
        await hre.run("verify:verify", {
            address: (await deployments.get('SwapChannel')).address,
        });
    }
};

module.exports.tags = ["SwapChannel"];
