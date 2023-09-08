const {
    sendLinkFromWhale
} = require("../deploy/fixtures/utils/helpers");

module.exports = async function (taskArgs, hre) {
    const { deployer } = await getNamedAccounts();
    const { 
        swapCalldata, 
        safetyBuffer, 
        swapHelperAddress,
        gasPrice,
        priceUSDtoLINK,
        priceETHtoUSD,
        value
    } = taskArgs;
    const networkName = hre.network.name;

    console.log(`Your address: ${deployer}. Network: ${networkName}`);
    console.log(`Estimating LINK price for swap calldata (safety buffer: ${safetyBuffer}): ${swapCalldata}...`);
    console.log(`SwapHelper address: ${swapHelperAddress}`);

    const swapHelperInstance = await hre.ethers.getContractAt(
        "SwapHelper",
        swapHelperAddress
    );
    
    // Its somewhat equal to the oracle expense executed routine.
    const estimatedGas = await swapHelperInstance.estimateGas.strategistFulfillSwap(
        swapCalldata, 
        value === "0" ? undefined : { value: hre.ethers.BigNumber.from(value) }
    );

    const PRECISION = 100;

    const bnGasPriceInWei = hre.ethers.BigNumber.from(gasPrice);
    const bnPriceUsdToLinkInWei = hre.ethers.BigNumber.from(priceUSDtoLINK);
    const bnPriceUsdToETHInWei = hre.ethers.BigNumber.from(priceETHtoUSD);
    const bnEstimatedGas = hre.ethers.BigNumber.from(estimatedGas);
    const bnSafetyBuffer = hre.ethers.BigNumber.from(safetyBuffer * PRECISION);
    
    const txCostInEth = bnEstimatedGas.mul(bnGasPriceInWei);
    const txCostInLink = txCostInEth.mul(bnPriceUsdToETHInWei).div(bnPriceUsdToLinkInWei);

    const resultTxCostInLink = txCostInLink.mul(bnSafetyBuffer).div(PRECISION);

    console.log(`An estimated cost of the swap is: ${hre.ethers.utils.formatUnits(resultTxCostInLink)} LINK`);
};
