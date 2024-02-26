const { expect } = require("chai");
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const {
  loadFixture,
  time,
  reset
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const { getEnv } = require("../../scripts/utils/env");
const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";
const NODE = getEnv("ARBITRUM_NODE");
const NET_FORK_BLOCK = getEnv("ARBITRUM_FORK_BLOCK");
const sgRouter = "0x0000000000000000000000000000000000000001";
const chainId = 42161;
const wantToken = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";

describe("Lock", function () {
    async function deployFixture() {
    await reset(NODE, Number(NET_FORK_BLOCK));
    const [deployer, governance, treasury, whale] = await ethers.getSigners();
    const BridgeMock = await ethers.getContractFactory("BridgeMock");
    const bridgeMock = await BridgeMock.deploy();
    await bridgeMock.waitForDeployment();

    const LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
    const lZEndpointMock = await LZEndpointMock.deploy();
    await lZEndpointMock.waitForDeployment();

    const StargateMock = await ethers.getContractFactory("StargateMock");
    const stargateMock = await StargateMock.deploy();
    await stargateMock.waitForDeployment();

    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await upgrades.deployProxy(
        SgBridge,
        [
            sgRouter,
            chainId
        ],
        {
          initializer: "initialize",
          kind: "transparent",
        }
      );
      await sgBridge.waitForDeployment();
      await sgBridge.setStargatePoolId(wantToken, 110, 1);

        const Vault = await ethers.getContractFactory("Vault");
        console.log(governance.address, await lZEndpointMock.getAddress());
        const vault = await upgrades.deployProxy(
        Vault,
        [
            governance.address,
            await lZEndpointMock.getAddress(),
            wantToken,
            sgRouter,
        ],
        {
            initializer: "initialize",
            kind: "transparent",
        }
    );
    await vault.waitForDeployment();

    const BeefyCompoundArb = await ethers.getContractFactory(
        "BeefyCompoundArb"
      );
      const beefyCompoundStrategy = await upgrades.deployProxy(
        BeefyCompoundArb,
        [
          await lZEndpointMock.getAddress(),
            deployer.address,
          deployer.address,
          wantToken,
          await vault.getAddress(),
          110,
          110,
          await sgBridge.getAddress(),
          sgRouter,
          "arb",
        ],
        {
          initializer: "initialize",
          kind: "transparent",
        }
      );
      await beefyCompoundStrategy.waitForDeployment();

      return {sgBridge, beefyCompoundStrategy, vault, deployer  };
    }
  
    it("Should set the right unlockTime", async function () {
      const { sgBridge, beefyCompoundStrategy, vault, deployer } = await loadFixture(deployFixture);
  
      console.log(await beefyCompoundStrategy.name())
    });
  
    
  
    
  });