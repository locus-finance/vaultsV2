const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers } = hre;
const {
  loadFixture,
  time,
  reset
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("BeefyPendleStrategy", function () {
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

  async function deployFixture() {
    const wantToken = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
    const sgRouter = "0x0000000000000000000000000000000000000001";
    const chainId = 110;
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
      const token = await ethers.getContractAt("IERC20", dealToken.address);

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

    const [deployer, governance] = await ethers.getSigners();
    const want = await ethers.getContractAt("IERC20", wantToken);

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
        deployer.address,
        await lZEndpointMock.getAddress(),
        wantToken,
        sgRouter,
      ],
      {
        initializer: "initialize",
        kind: "uups",
      }
    );
    await vault.waitForDeployment();

    const governanceRole = "0x35a7846a2a701fff6f9d61a46ebff5da578c5dcee8bdf361c569f9ea4ee64771"; // keccak256("GOVERNANCE")
    const grantRoleTx = await vault.grantRole(governanceRole, deployer.address);
    await grantRoleTx.wait();

    const libraryNames = ["BeefyPendleStrategyLib"];

    const libraries = {};
    if (libraryNames !== undefined) {
      console.log('Found libraries to deploy and link!');
      for (const libraryName of libraryNames) {
        const library = await ethers.deployContract(libraryName);
        const libAddress = await library.getAddress();
        console.log(`Deployed library: ${libraryName} - ${libAddress}`);
        libraries[libraryName] = libAddress;
      }
    } else {
      console.log("No external libraries for this strategy. Continue...");
    }

    let factoryParams;
    if (libraryNames.length > 0) {
      factoryParams = {
        libraries
      }
    }
    const BeefyPendleStrategy = await ethers.getContractFactory("BeefyPendleStrategy", factoryParams);
    const strategy = await upgrades.deployProxy(
      BeefyPendleStrategy,
      [
        await lZEndpointMock.getAddress(),
        deployer.address,
        deployer.address,
        wantToken,
        await vault.getAddress(),
        110,
        110,
        await sgBridge.getAddress(),
        sgRouter
      ],
      {
        initializer: "initialize",
        kind: "uups",
        unsafeAllow: [
          "external-library-linking"
        ]
      }
    );
    await strategy.waitForDeployment();

    const VaultToken = await ethers.getContractFactory("VaultToken");
    const vaultToken = await upgrades.deployProxy(
      VaultToken,
      [
        deployer.address,
        await vault.getAddress()
      ],
      {
        initializer: "initialize",
        kind: "uups",
      }
    );
    await vaultToken.waitForDeployment();
    await vaultToken.connect(deployer).approve(await vault.getAddress(), ethers.MaxUint256);

    const setSgLzSettingsTx = await vault.setSgLzSettings(
      await bridgeMock.getAddress(),
      await sgBridge.getAddress(),
      9000000
    );
    await setSgLzSettingsTx.wait();

    const setDepositLimitTx = await vault.setDepositLimit(ethers.parseUnits("10000000", 6));
    await setDepositLimitTx.wait();

    const setVaultTokenTx = await vault.setVaultToken(await vaultToken.getAddress());
    await setVaultTokenTx.wait();

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

    return { sgBridge, strategy, vault, deployer, want, vaultToken };
  }

  async function sign(strategy, signer) {
    const signPayload = await strategy.strategistSignMessageHash();
    const signature = await signer.signMessage(
      ethers.getBytes(signPayload)
    );
    return signature;
  }

  let sgBridge;
  let strategy;
  let vault;
  let deployer;
  let vaultToken;

  beforeEach(async function () {
    const fixtureData = await loadFixture(deployFixture);
    sgBridge = fixtureData.sgBridge;
    strategy = fixtureData.strategy;
    vault = fixtureData.vault;
    vaultToken = fixtureData.vaultToken;
    deployer = fixtureData.deployer;
  });

  it('should deposit, harvest and withdraw', async () => {
    const { strategy, vault, deployer, want } = await loadFixture(deployFixture);
    let signature = await sign(strategy, deployer);

    const balanceBefore = await want.balanceOf(deployer.address);
    // console.log(balanceBefore.toString());
    await want.connect(deployer).approve(vault, ethers.parseEther("10000"))
    await vault.connect(deployer)["deposit(uint256,address)"](balanceBefore, deployer.address);
    expect(await want.balanceOf(vault)).to.equal(balanceBefore);

    let totalDebt = (await vault.strategies(110, strategy)).totalDebt;
    let debtOutstanding = await vault.debtOutstanding(110, strategy);
    let credit = await vault.creditAvailable(110, strategy);
    let ratio = (await vault.strategies(110, strategy)).debtRatio;

    await strategy.connect(deployer).harvest(totalDebt, debtOutstanding, credit, ratio, signature);
    expect(await strategy.estimatedTotalAssets()).to.be.closeTo(
      balanceBefore,
      ethers.parseUnits("100", 6)
    );
    expect(await want.balanceOf(await strategy.getAddress())).to.eq(0);

    let eta = await strategy.estimatedTotalAssets();
    await time.increase(60 * 60 * 24 * 15)

    totalDebt = (await vault.strategies(110, strategy)).totalDebt
    debtOutstanding = await vault.debtOutstanding(110, strategy)
    credit = await vault.creditAvailable(110, strategy)
    ratio = (await vault.strategies(110, strategy)).debtRatio
    signature = await sign(strategy, deployer);

    await strategy.connect(deployer).harvest(totalDebt, debtOutstanding, credit, ratio, signature);
    expect(await strategy.estimatedTotalAssets()).to.be.greaterThan(eta);

    await vault
      .connect(deployer)
    ["withdraw(uint256,address,uint256)"](
      await vaultToken.balanceOf(deployer.address),
      deployer.address,
      1000
    );

    let tx = await vault.connect(deployer).handleWithdrawals();
    await tx.wait();
    expect((await want.balanceOf(deployer.address))).to.be.lessThan(
      balanceBefore
    );
  });
});
