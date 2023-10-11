const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const axios = require("axios");
const { getEnv } = require("../utils");

describe("SwapHelper", function () {
  const ONE_INCH_ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // ETH
  const ONE_INCH_TOKEN_ADDRESS = "0x111111111117dC0aa78b770fA6A738034120C302"; // 1INCH
  const ORACLE_ADDRESS = "0x0168B5FcB54F662998B0620b9365Ae027192621f";
  const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  const ETH_WHALE = "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5";
  const LINK_WHALE = "0xF977814e90dA44bFA03b6295A0616a897441aceC";
  const MOCKED_AMOUNT = ethers.utils.parseEther("1");
  const MOCKED_SLIPPAGE = 1;

  let deployer;
  let swapHelperInstance;

  const mintNativeTokens = async (signer, amountHex) => {
    await hre.network.provider.send("hardhat_setBalance", [
      signer.address || signer,
      amountHex,
    ]);
  };
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
  };

  const mockOracleQuote = async (src, dst, amount) => {
    let rawResult;
    try {
      rawResult = await axios({
        method: "get",
        url: "https://api.1inch.dev/swap/v5.2/1/quote",
        headers: {
          accept: "application/json",
          Authorization: `Bearer ${getEnv("ONE_INCH_API_KEY")}`,
        },
        params: { src, dst, amount },
        responseType: "json",
      });
    } catch (error) {
      console.log(error);
    }
    return rawResult.data.toAmount;
  };

  const mockOracleSwapCalldata = async (
    src,
    dst,
    from,
    amount,
    slippage,
    receiver
  ) => {
    let rawResult;
    try {
      rawResult = await axios({
        method: "get",
        url: "https://api.1inch.dev/swap/v5.2/1/swap",
        headers: {
          accept: "application/json",
          Authorization: `Bearer ${getEnv("ONE_INCH_API_KEY")}`,
        },
        params: {
          src,
          dst,
          amount,
          slippage,
          from,
          receiver,
          disableEstimate: true,
        },
        responseType: "json",
      });
    } catch (error) {
      console.log(error);
    }
    return rawResult.data.tx.data;
  };

  const sendLinkFromWhale = async (toAddress, linkAmount) => {
    const linkInstance = await hre.ethers.getContractAt("IERC20", LINK_ADDRESS);
    await withImpersonatedSigner(LINK_WHALE, async (linkWhaleSigner) => {
      await mintNativeTokens(LINK_WHALE, "0x100000000000000000");
      await linkInstance
        .connect(linkWhaleSigner)
        .transfer(toAddress, linkAmount);
    });
  };

  beforeEach(async function () {
    await deployments.fixture(["MockSwapHelperSubscriber", "SwapHelper"]);
    const accounts = await getNamedAccounts();
    deployer = accounts.deployer;
    await deployments.execute(
      "SwapHelper",
      { from: deployer, log: true },
      "addSubscriber",
      (
        await get("MockSwapHelperSubscriber")
      ).address
    );
    await sendLinkFromWhale(
      (
        await get("SwapHelper")
      ).address,
      hre.ethers.utils.parseEther("1000")
    );
    swapHelperInstance = await hre.ethers.getContractAt(
      "SwapHelper",
      (
        await get("SwapHelper")
      ).address
    );
  });

  it("should perform a quote use case", async function () {
    const mockedOutAmount = await mockOracleQuote(
      ONE_INCH_ETH_ADDRESS,
      ONE_INCH_TOKEN_ADDRESS,
      MOCKED_AMOUNT
    );

    await deployments.execute(
      "SwapHelper",
      { from: deployer, log: true },
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
    expect((await swapHelperInstance.quoteBuffer()).outAmount).to.be.equal(0);
    expect(await swapHelperInstance.isReadyToFulfillQuote()).to.be.false;

    const mockSubscriberInstance = await hre.ethers.getContractAt(
      "MockSwapHelperSubscriber",
      (
        await get("MockSwapHelperSubscriber")
      ).address
    );
    await expect(swapHelperInstance.strategistFulfillQuote(mockedOutAmount))
      .to.emit(mockSubscriberInstance, "Notified")
      .withArgs(
        ONE_INCH_ETH_ADDRESS,
        ONE_INCH_TOKEN_ADDRESS,
        mockedOutAmount,
        MOCKED_AMOUNT
      );
  });

  it("should perform a swap use case", async function () {
    const mockedSwapCalldata = await mockOracleSwapCalldata(
      ONE_INCH_ETH_ADDRESS,
      ONE_INCH_TOKEN_ADDRESS,
      ETH_WHALE,
      MOCKED_AMOUNT,
      MOCKED_SLIPPAGE,
      deployer
    );
    await deployments.execute(
      "SwapHelper",
      { from: deployer, log: true, value: MOCKED_AMOUNT },
      "requestSwap",
      ONE_INCH_ETH_ADDRESS,
      ONE_INCH_TOKEN_ADDRESS,
      MOCKED_AMOUNT,
      MOCKED_SLIPPAGE
    );
    await expect(
      swapHelperInstance.strategistFulfillSwap(mockedSwapCalldata, {
        value: MOCKED_AMOUNT,
      })
    )
      .to.emit(swapHelperInstance, "StrategistInterferred")
      .withArgs(1);
  });
});
