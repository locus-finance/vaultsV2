const { pt } = require("../utils");
const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";

module.exports = async function (_, hre) {
    const networkName = hre.network.name;
    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await SgBridge.attach(bridgeConfig[networkName].sgBridge);

    const { deployer } = await getNamedAccounts();

    const currentChainId = bridgeConfig[networkName].chainId;
    await pt(sgBridge.setCurrentChainId(currentChainId));
    await pt(sgBridge.setWhitelist(deployer));

    for (const [_, config] of Object.entries(bridgeConfig)) {
        await pt(
            sgBridge.setSupportedDestination(config.chainId, config.sgBridge)
        );
        await pt(
            sgBridge.setStargatePoolId(
                bridgeConfig[networkName][TOKEN].address,
                config.chainId,
                config[TOKEN].poolId
            )
        );
    }
};
