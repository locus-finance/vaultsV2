const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const axios = require("axios");
const { getEnv } = require("../utils");
const {
    sendLinkFromWhale,
    getOracleSwapCalldata,
    getOracleQuote
} = require("../deploy/fixtures/utils/helpers");

describe("SwapHelper", () => {
    const ONE_INCH_ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // ETH
    const ONE_INCH_TOKEN_ADDRESS = "0x111111111117dC0aa78b770fA6A738034120C302"; // 1INCH
    const ETH_WHALE = "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5";
    const MOCKED_AMOUNT = ethers.utils.parseEther('1');
    const MOCKED_SLIPPAGE = 1;

    let deployer;
    let swapHelperInstance;

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
        await sendLinkFromWhale((await get("SwapHelper")).address, hre.ethers.utils.parseEther("1000"));
        swapHelperInstance = await hre.ethers.getContractAt(
            "SwapHelper",
            (await get("SwapHelper")).address
        );
    });

    it('should execute Hardhat task of an estimation of the swap costs in mocked LINK price', async () => {
        const mockedSwapCalldata = await getOracleSwapCalldata(
            getEnv,
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            ETH_WHALE,
            MOCKED_AMOUNT,
            MOCKED_SLIPPAGE,
            deployer,
            false
        );
        await deployments.execute(
            "SwapHelper",
            {from: deployer, log: true, value: MOCKED_AMOUNT},
            "requestSwap",
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            MOCKED_AMOUNT,
            MOCKED_SLIPPAGE
        );
        await hre.run("estimateSwap", {
            swapCalldata: mockedSwapCalldata,
            swapHelperAddress: swapHelperInstance.address,
            gasPrice: (await hre.ethers.provider.getGasPrice()).toString(),
            priceUSDtoLINK: "3", // <- random value
            priceETHtoUSD: "5", // <- random value
            safetyBuffer: "1.5",
            value: MOCKED_AMOUNT.toString()
        });
    });

    xit('should perform a quote use case', async () => {
        const mockedOutAmount = await getOracleQuote(
            getEnv,
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            MOCKED_AMOUNT
        );
        
        await deployments.execute(
            "SwapHelper",
            {from: deployer, log: true},
            "requestQuote",
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            MOCKED_AMOUNT
        );
        expect(
            (await swapHelperInstance.quoteBuffer()).swapInfo.srcToken
        ).to.be.equal(ONE_INCH_ETH_ADDRESS);
        expect(
            (await swapHelperInstance.quoteBuffer()).swapInfo.dstToken
        ).to.be.equal(ONE_INCH_TOKEN_ADDRESS);
        expect(
            (await swapHelperInstance.quoteBuffer()).swapInfo.inAmount
        ).to.be.equal(MOCKED_AMOUNT);
        expect(
            (await swapHelperInstance.quoteBuffer()).outAmount
        ).to.be.equal(0);
        expect(
            await swapHelperInstance.isReadyToFulfillQuote()
        ).to.be.false;

        const mockSubscriberInstance = await hre.ethers.getContractAt(
            "MockSwapHelperSubscriber",
            (await get("MockSwapHelperSubscriber")).address
        );
        await expect(swapHelperInstance.strategistFulfillQuote(mockedOutAmount)).to.emit(
            mockSubscriberInstance, "MockNotified"
        ).withArgs(
            ONE_INCH_ETH_ADDRESS, ONE_INCH_TOKEN_ADDRESS, mockedOutAmount, MOCKED_AMOUNT
        );
    });

    xit('should perform a swap use case', async () => {
        const mockedSwapCalldata = await getOracleSwapCalldata(
            getEnv,
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            ETH_WHALE,
            MOCKED_AMOUNT,
            MOCKED_SLIPPAGE,
            deployer
        );
        await deployments.execute(
            "SwapHelper",
            {from: deployer, log: true, value: MOCKED_AMOUNT},
            "requestSwap",
            ONE_INCH_ETH_ADDRESS,
            ONE_INCH_TOKEN_ADDRESS,
            MOCKED_AMOUNT,
            MOCKED_SLIPPAGE
        );
        await expect(
            swapHelperInstance.strategistFulfillSwap(mockedSwapCalldata, {value: MOCKED_AMOUNT})
        ).to.emit(swapHelperInstance, "StrategistInterferred").withArgs(1);
    });
});
