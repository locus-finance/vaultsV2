const { expect } = require("chai");
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const {
  loadFixture,
  time,
  reset
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const abi = ["function approve(address,uint256) external",
"function balanceOf(address) external view returns(uint256)",
"function transfer(address,uint256) external"
]

const { getEnv } = require("../../scripts/utils/env");
const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";
const NODE = getEnv("ARBITRUM_NODE");
const NET_FORK_BLOCK = getEnv("ARBITRUM_FORK_BLOCK");
const sgRouter = "0x0000000000000000000000000000000000000001";
const chainId = 42161;
const wantToken = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
const TOKENS = {
    USDC: {
      address: "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
      whale: "0x62383739d68dd0f844103db8dfb05a7eded5bbe6",
      decimals: 6,
    },
    ETH: {
        whale: "0xb38e8c17e38363af6ebdcb3dae12e0243582891d",
      },
  };

async function dealTokensToAddress(
    address,
    dealToken,
    amountUnscaled = "100"
  ) {
    const token = await ethers.getContractAt(abi, dealToken.address);

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
      value: ethers.parseEther("50"),
    });

    await token
      .connect(tokenWhale)
      .transfer(address, ethers.parseUnits(amountUnscaled, dealToken.decimals));
  }

  async function sign(strategy, signer) {
    const signPayload = await strategy.strategistSignMessageHash();
    const signature = await signer.signMessage(
        ethers.getBytes(signPayload)
    );
    return signature;
  }

describe("BeefyCompound Arb", function () {
    async function deployFixture() {
    await reset(NODE, Number(NET_FORK_BLOCK));
    const [deployer, governance, treasury, whale] = await ethers.getSigners();
    const want = await ethers.getContractAt(abi, wantToken);

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

    const Strategy = await ethers.getContractFactory(
        "BeefyCompoundArb"
      );
      const strategy = await upgrades.deployProxy(
        Strategy,
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
      await strategy.waitForDeployment();

      await vault["addStrategy(uint16,address,uint256,uint256,address)"](
        110,
        await strategy.getAddress(),
        10000,
        0,
        deployer.address
      );

      await dealTokensToAddress(deployer.address, TOKENS.USDC, "1000");

      return {sgBridge, strategy, vault, deployer, want  };
    }
  
    it("Should get the right name", async function () {
      const { sgBridge, strategy, vault, deployer } = await loadFixture(deployFixture);
      expect(await strategy.vault()).to.equal(await vault.getAddress());
      expect(await strategy.name()).to.eq("Beefy - Compound arb")
    });

    it("Should deposit -> harvest -> withdraw the right name", async function () {
        const { sgBridge, strategy, vault, deployer, want } = await loadFixture(deployFixture);
        const signature = await sign(strategy,deployer);
        console.log(signature);
        console.log(ethers.isAddressable(vault));
        const balanceBefore = await want.balanceOf(deployer.address);
        console.log(balanceBefore);
        await want.connect(deployer).approve(vault, ethers.parseEther("10000"))
        await vault.connect(deployer)["deposit(uint256,address)"](balanceBefore, deployer.address);
        expect(await want.balanceOf(vault)).to.equal(balanceBefore);
        const totalDebt = (await vault.strategies(110, strategy)).totalDebt
        const debtOutstanding = await vault.debtOutstanding(110, strategy)
        const credit = await vault.creditAvailable(110, strategy)
        const ratio = (await vault.strategies(110, strategy)).debtRatio
        console.log(totalDebt, debtOutstanding, credit, ratio);
        await strategy.connect(deployer).harvest(totalDebt, debtOutstanding, credit, ratio, signature );
        // expect(await strategy.estimatedTotalAssets()).to.be.closeTo(
        //   balanceBefore,
        //   ethers.utils.parseUnits("100", 6)
        // );
        // We are dropping some USDC to staking contract to simulate profit from JOE staking
        // await dealTokensToAddress(whale.address, TOKENS.USDC, "1000000");
        // const deposit = await want.balanceOf(whale.address);
        // await ethers.provider.send("evm_increaseTime", [100 * 24 * 60 * 60]);
    
        // await vault.connect(whale)["deposit(uint256)"](deposit);
        // const tx = await strategy.connect(deployer).harvest();
    
        // await tx.wait();
        // expect(Number(await strategy.rewardss())).to.be.greaterThan(0);
        // await ethers.provider.send("evm_increaseTime", [50 * 24 * 60 * 60]);
    
        // Previous harvest indicated some profit and it was withdrawn to vault
        // expect(Number(await want.balanceOf(vault.address))).to.be.greaterThan(0);
        // All profit from strategy was withdrawn to vault
        // expect(Number(await want.balanceOf(strategy.address))).to.be.equal(0);
    
        // Vault reinvesing its profit back to strategy
        // await strategy.connect(deployer).harvest();
        // expect(Number(await strategy.estimatedTotalAssets())).to.be.greaterThan(
        //   Number(balanceBefore)
        // );
    
        // Mining blocks for unlocking all profit so whale can withdraw
        // mine(36000);
    
        // await vault
        //   .connect(whale)
        //   ["withdraw(uint256,address,uint256)"](
        //     await vault.balanceOf(whale.address),
        //     whale.address,
        //     1000
        //   );
        // expect(Number(await want.balanceOf(whale.address))).to.be.greaterThan(
        //   Number(balanceBefore)
        // );
        
        
      });
  
    
  
    
  });