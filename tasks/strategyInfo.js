const bridgeConfig = require("../constants/bridgeConfig.json");

module.exports = async function (taskArgs, hre) {
    const networkName = hre.network.name;
    const { strategyChain } = taskArgs;

    const vault = await ethers.getContractAt(
        "Vault",
        bridgeConfig[networkName].vault
    );

    const config = bridgeConfig[strategyChain];
    const strategyInfo = await vault.strategies(
        config.chainId,
        config.TestStrategy
    );
    const debtOutstanding = await vault.debtOutstanding(
        config.chainId,
        config.TestStrategy
    );
    const creditAvailable = await vault.creditAvailable(
        config.chainId,
        config.TestStrategy
    );

    console.log(`Total debt=${Number(strategyInfo.totalDebt)}`);
    console.log(`Debt outstanding=${Number(debtOutstanding)}`);
    console.log(`Credit available=${Number(creditAvailable)}`);
    console.log(`Debt ratio=${Number(strategyInfo.debtRatio)}`);
};
