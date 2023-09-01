const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const axios = require("axios");
const { getEnv } = require("../utils");

describe("SwapHelper", () => {
    const ONE_INCH_ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // ETH
    const ONE_INCH_TOKEN_ADDRESS = "0x111111111117dc0aa78b770fa6a738034120c302"; // 1INCH
    const ORACLE_ADDRESS = "0x0168B5FcB54F662998B0620b9365Ae027192621f";
    const ETH_WHALE = "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5";
    const MOCKED_AMOUNT = ethers.utils.parseEther('1');
    const MOCKED_REQUEST_ID = 1;
    const MOCKED_SLIPPAGE = 1;
    let deployer;

    const mintNativeTokens = async (signer, amountHex) => {
        await hre.network.provider.send("hardhat_setBalance", [
            signer.address || signer,
            amountHex
        ]);
    }
    const withImpersonatedSigner = async (signerAddress, action) => {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [signerAddress],
        });

        const impersonatedSigner = await hre.ethers.getSigner(signerAddress);
        await action(impersonatedSigner);

        await hre.network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [signerAddress],
        });
    }

    const mockOracleQuote = async (src, dst, amount) => {
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

    const mockOracleSwapCalldata = async (src, dst, from, amount, slippage, receiver) => {
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

    beforeEach(async () => {
        await deployments.fixture(['MockSwapHelperSubscriber', 'SwapHelper']);
        const accounts = await getNamedAccounts();
        deployer = accounts.deployer;
        await deployments.execute(
            "SwapHelper",
            {from: deployer, log: true},
            "addSubscriber",
            (await get("MockSwapHelperSubscriber")).address
        );
    });

    it('should perform a quote use case', async () => {
        console.log(
            await mockOracleQuote(
                ONE_INCH_ETH_ADDRESS,
                ONE_INCH_TOKEN_ADDRESS,
                MOCKED_AMOUNT
            )
        );
    });

    it('should perform a swap use case', async () => {
        await mintNativeTokens(
            (await get("SwapHelper")).address, 
            MOCKED_AMOUNT.toHexString()
        );
        // console.log(
        //     await mockOracleSwapCalldata(
        //         ONE_INCH_ETH_ADDRESS,
        //         ONE_INCH_TOKEN_ADDRESS,
        //         ETH_WHALE,
        //         MOCKED_AMOUNT,
        //         MOCKED_SLIPPAGE,
        //         deployer
        //     )
        // );
    });
});
