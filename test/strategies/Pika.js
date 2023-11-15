const {
  loadFixture,
  mine,
  time,
  reset,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { utils, BigNumber } = require("ethers");
const { ethers } = require("hardhat");

const { getEnv } = require("../../scripts/utils/env");
const networkConfig = require("../../constants/networks.json");
const { parseEther } = require("ethers/lib/utils");

const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";
const OPTIMISM_NODE_URL = getEnv("OPTIMISM_NODE");
const OPTIMISM_FORK_BLOCK = getEnv("OPTIMISM_FORK_BLOCK");

describe("PIKA strategy", function () {
  const TOKENS = {
    USDC: {
      address: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
      whale: "",
      decimals: 6,
    },
  };
  const TOKEN = "USDC";

  async function deployContractAndSetVariables() {
    await reset(OPTIMISM_NODE_URL, Number(OPTIMISM_FORK_BLOCK));

    const [deployer] = await ethers.getSigners();
    const USDC_ADDRESS = TOKENS.USDC.address;
    const want = await ethers.getContractAt(IERC20_SOURCE, USDC_ADDRESS);

    console.log(
      `Your address: ${deployer.address}. Network: ${hre.network.name}`
    );

    const config = networkConfig.optimism;

    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await upgrades.deployProxy(SgBridge, [config.sgRouter], {
      initializer: "initialize",
      kind: "transparent",
    });
    await sgBridge.deployed();

    console.log("SgBridge deployed to:", sgBridge.address);

    const Vault = await ethers.getContractFactory("Vault");
    const vault = await upgrades.deployProxy(
      Vault,
      [
        deployer.address,
        config.lzEndpoint,
        TOKENS.USDC.address,
        sgBridge.address,
        config.sgRouter,
      ],
      {
        initializer: "initialize",
        kind: "transparent",
      }
    );
    await vault.deployed();

    console.log("Vault deployed to:", vault.address);

    const PikaStrategy = await ethers.getContractFactory("PikaStrategy");
    const pikaStrategy = await upgrades.deployProxy(
      PikaStrategy,
      [
        config.lzEndpoint,
        deployer.address,
        TOKENS.USDC.address,
        vault.address,
        config.chainId,
        sgBridge.address,
        config.sgRouter,
        0,
      ],
      {
        initializer: "initialize",
        kind: "transparent",
      }
    );
    await pikaStrategy.deployed();

    console.log("pikaStrategy deployed to:", pikaStrategy.address);

    // await dealTokensToAddress(whale.address, TOKENS.USDC, "1000");
    // await want
    //   .connect(whale)
    //   ["approve(address,uint256)"](vault.address, ethers.constants.MaxUint256);

    return {
      vault,
      deployer,
      pikaStrategy,
      want,
    };
  }

  async function dealTokensToAddress(
    address,
    dealToken,
    amountUnscaled = "100"
  ) {
    const token = await ethers.getContractAt(IERC20_SOURCE, dealToken.address);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [dealToken.whale],
    });
    const tokenWhale = await ethers.getSigner(dealToken.whale);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [TOKENS.ETH.whale],
    });
    const ethWhale = await ethers.getSigner(TOKENS.ETH.whale);

    await ethWhale.sendTransaction({
      to: tokenWhale.address,
      value: utils.parseEther("50"),
    });

    await token
      .connect(tokenWhale)
      .transfer(address, utils.parseUnits(amountUnscaled, dealToken.decimals));
  }

  it("should deploy strategy", async function () {
    const { vault, pikaStrategy } = await loadFixture(
      deployContractAndSetVariables
    );
    expect(await pikaStrategy.vault()).to.equal(vault.address);
    expect(await pikaStrategy.name()).to.equal("Pika V4 Strategy");
    // console.log(ethers.utils.parseEther("1")._hex);
    // console.log(await pikaStrategy.check(ethers.utils.parseEther("1")._hex));
    // console.log(BigNumber.from(ethers.utils.parseEther("1")._hex));
    // console.log(await pikaStrategy.ethToWantMyFunc(1000000000));
    // console.log(
    //   await pikaStrategy.getPool(
    //     "0x4200000000000000000000000000000000000006",
    //     "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
    //     10000
    //   )
    // );
    console.log(await pikaStrategy.getFactoryOwner());
  });
});
