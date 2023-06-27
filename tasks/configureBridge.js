const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";

module.exports = async function ({ getNamedAccounts }, hre) {
    const networkName = hre.network.name;
    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await SgBridge.attach(bridgeConfig[networkName].sgBridge);

    const { deployer } = await getNamedAccounts();

    const currentChainId = bridgeConfig[networkName].chainId;
    await sgBridge.setCurrentChainId(currentChainId).then((tx) => tx.wait());
    await sgBridge.setWhitelist(deployer.address).then((tx) => tx.wait());

    for (const [_, config] of Object.entries(bridgeConfig)) {
        await sgBridge
            .setSupportedDestination(config.chainId, config.sgBridge)
            .then((tx) => tx.wait());
        await sgBridge
            .setStargatePoolId(
                bridgeConfig[networkName][TOKEN].address,
                config.chainId,
                config[TOKEN].poolId
            )
            .then((tx) => tx.wait());
    }
};
