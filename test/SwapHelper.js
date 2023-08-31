const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const axios = require("axios");
const { getEnv } = require("../utils");

describe("SwapHelper", () => {
    const ONE_INCH_ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
    const ONE_INCH_TOKEN_ADDRESS = "0x111111111117dc0aa78b770fa6a738034120c302";
    const MOCKED_REQUEST_ID = 1;
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

    const mockOracleQuote = async (srcAddress, dstAddress, amount) => {
        
    }

    const mockOracleSwapCalldata = async (srcAddress, dstAddress, amount, slippage) => {

    }

    beforeEach(async () => {
        await deployments.fixture(['MockSwapHelperSubscriber', 'SwapHelper']);
        const accounts = await getNamedAccounts();
        deployer = accounts.deployer;
    });

    it('should perform a quote use case', async () => {

    });

    it('should perform a swap use case', async () => {

    });
});
