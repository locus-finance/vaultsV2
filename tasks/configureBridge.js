const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";

module.exports = async function (_, hre) {
    const networkName = hre.network.name;
    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await SgBridge.attach(bridgeConfig[networkName].sgBridge);

    const currentChainId = bridgeConfig[networkName].chainId;
    await sgBridge.setCurrentChainId(currentChainId);

    for (const [_, config] of Object.entries(bridgeConfig)) {
        await sgBridge.setSupportedDestination(config.chainId, config.sgBridge);
        await sgBridge.setStargatePoolId(
            bridgeConfig[networkName][TOKEN].address,
            config.chainId,
            config[TOKEN].poolId
        );
    }
};
