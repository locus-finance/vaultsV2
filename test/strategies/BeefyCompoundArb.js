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
const chainId = 110;
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

      const ethWhale = await ethers.getSigner(TOKENS.ETH.whale);

    await ethWhale.sendTransaction({
      to: await vault.getAddress(),
      value: ethers.parseEther("1"),
    });
    await ethWhale.sendTransaction({
        to: await strategy.getAddress(),
        value: ethers.parseEther("1"),
      });

      await vault.setSgBridge(sgBridge);

      return {sgBridge, strategy, vault, deployer, want  };
    }
  
    it("Should get the right name", async function () {
      const { sgBridge, strategy, vault, deployer } = await loadFixture(deployFixture);
      expect(await strategy.vault()).to.equal(await vault.getAddress());
      expect(await strategy.name()).to.eq("Beefy - Compound arb")
    });

    it("Should deposit -> harvest -> withdraw the right name", async function () {
        const { sgBridge, strategy, vault, deployer, want } = await loadFixture(deployFixture);
        let signature = await sign(strategy,deployer);
        const balanceBefore = await want.balanceOf(deployer.address);
        await want.connect(deployer).approve(vault, ethers.parseEther("10000"))
        await vault.connect(deployer)["deposit(uint256,address)"](balanceBefore, deployer.address);
        expect(await want.balanceOf(vault)).to.equal(balanceBefore);
        let totalDebt = (await vault.strategies(110, strategy)).totalDebt
        let debtOutstanding = await vault.debtOutstanding(110, strategy)
        let credit = await vault.creditAvailable(110, strategy)
        let ratio = (await vault.strategies(110, strategy)).debtRatio
        await strategy.connect(deployer).harvest(totalDebt, debtOutstanding, credit, ratio, signature);
        expect(await strategy.estimatedTotalAssets()).to.be.closeTo(
          balanceBefore,
          ethers.parseUnits("100", 6)
        );
        expect(await want.balanceOf(await strategy.getAddress())).to.eq(0)
        let eta = await strategy.estimatedTotalAssets();
        await time.increase(60 * 60 * 24 * 15)
        totalDebt = (await vault.strategies(110, strategy)).totalDebt
        debtOutstanding = await vault.debtOutstanding(110, strategy)
        credit = await vault.creditAvailable(110, strategy)
        ratio = (await vault.strategies(110, strategy)).debtRatio
        signature = await sign(strategy,deployer);
        await strategy.connect(deployer).harvest(totalDebt, debtOutstanding, credit, ratio, signature);
    
        
        expect(await strategy.estimatedTotalAssets()).to.be.greaterThan(eta);
        await vault
          .connect(deployer)
          ["withdraw(uint256,address,uint256)"](
            await vault.balanceOf(deployer.address),
            deployer.address,
            1000
          );
          let tx  = await vault.connect(deployer).handleWithdrawals();
          await tx.wait();
           tx  = await vault.connect(deployer).handleWithdrawals();
        expect((await want.balanceOf(deployer.address))).to.be.greaterThan(
          balanceBefore
        );
      });
  
    
  
    
  });