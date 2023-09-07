const axios = require("axios");

module.exports = async function (taskArgs, hre) {
    const { deployer } = await getNamedAccounts();
    const { swapCalldata } = taskArgs;
    const networkName = hre.network.name;

    console.log(`Your address: ${deployer}. Network: ${networkName}`);
    console.log(`Estimating LINK price for swap calldata: ${swapCalldata}...`);

    const getOracleQuote = async (src, dst, amount) => {
        let rawResult;
        try {
            rawResult = await axios({
                method: "get",
                url: 'https://api.1inch.dev/swap/v5.2/1/quote',
                headers: {
                    "accept": "application/json",
                    "Authorization": `Bearer ${getEnv("ONE_INCH_API_KEY")}`
                },
                params: {src, dst, amount},
                responseType: 'json'
            });
        } catch (error) {
            console.log(error);
        }
        return rawResult.data.toAmount;
    }

    const getOracleSwapCalldata = async (src, dst, from, amount, slippage, receiver) => {
        let rawResult;
        try {
            rawResult = await axios({
                method: "get",
                url: 'https://api.1inch.dev/swap/v5.2/1/swap',
                headers: {
                    "accept": "application/json",
                    "Authorization": `Bearer ${getEnv("ONE_INCH_API_KEY")}`
                },
                params: {src, dst, amount, slippage, from, receiver, disableEstimate: true},
                responseType: 'json'
            });
        } catch (error) {
            console.log(error);
        }
        return rawResult.data.tx.data;
    }

    
};
