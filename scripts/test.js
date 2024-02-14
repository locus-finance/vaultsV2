// const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const {
  impersonateAccount, mine, time
} = require("@nomicfoundation/hardhat-network-helpers");
const ABI = [
  "function estimatedTotalAssets() external view returns(uint256)",
  "function setManagementFee(uint256) external",
  "function swapUsdPlusToWant() external",
  "function balanceOf(address) external view returns(uint256)",
  "function adjustPosition(uint256)",
  "function harvest(uint256,uint256,uint256,uint256,bytes) external",
  "function migrate(address) external",
  "function owner() external view returns(address)",
  "function migrateStrategy(uint16,address,address) external"
];
const { vaultChain } = require("../utils");

const TOKEN = "USDC";

async function main() {
  const sigs = await ethers.getSigners();
  const provider = new ethers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  console.log(1);
  // await deployStrategy()

  await impersonateAccount("0x942f39555D430eFB3230dD9e5b86939EFf185f0A")

  const governance = await ethers.provider.getSigner(
    "0x942f39555D430eFB3230dD9e5b86939EFf185f0A"
  );


  const tx2 = await sigs[0].sendTransaction({
    to: await governance.getAddress(),
    value: ethers.parseEther("300"),
  });
  await tx2.wait();
  console.log("funds send");
  const strategy = await ethers.getContractAt(
    ABI,
    "0xA93e1DfF89dcCCA3C3CadFd0A28aD071C230eD84"
  );

  const newStrategy = await ethers.getContractAt(
    ABI,
    "0xC7f602302cAf28340BfDE77a24Ac9d93A10dB6BA"
  );

  const vault = await ethers.getContractAt(
    ABI,
    "0x2a889E9ef10c7Bd607473Aadc8c806c4511EB26f"
  );
  // await mine(1000);
  // await time.increase(1000)
  console.log(await vault.owner())
  console.log(await strategy.connect(governance).estimatedTotalAssets());
  console.log(await newStrategy.connect(governance).estimatedTotalAssets());
  console.log(await vault.connect(governance).migrateStrategy(110, await strategy.getAddress() ,await newStrategy.getAddress(), { gasLimit: 30000000 }));
  console.log(await strategy.connect(governance).estimatedTotalAssets());
  console.log(await newStrategy.connect(governance).estimatedTotalAssets());
}

async function upgradeVault() {
  const provider = new ethers.providers.JsonRpcProvider({
    url: "http://127.0.0.1:8545",
  });
  await impersonateAccount("0x3C2792d5Ea8f9C03e8E73738E9Ed157aeB4FeCBe")

  console.log("upgrading");
  const owner = await ethers.provider.getSigner(
    "0x6194738930D4239e596C1CC624Fb1cEa4ebE2665"
  );
  console.log(owner);
  console.log("upgrading");
  // await proxy
  //   .connect(owner)
  //   .transferOwnership("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  // console.log(await proxy.owner());
  const vault = await hre.ethers.getContractFactory("HopStrategy", owner);
  console.log("upgrading");
  const upgraded = await hre.upgrades.upgradeProxy(
    "0x205D6195fa2ebFE04CDa0be91365c43aA9e1b739",
    vault
  );
  console.log("upgrading");
  console.log("Successfully upgraded implementation of", upgraded.address);
}

async function deployStrategy() {

  const sigs = await hre.ethers.getSigners();

  const config = bridgeConfig["arbitrumOne"];
  const vaultConfig = bridgeConfig[vaultChain("arbitrumOne")];
  const HopStrategy = await ethers.getContractFactory("HopStrategy");
  const hopStrategy = await upgrades.deployProxy(
    HopStrategy,
    [
      config.lzEndpoint,
      config.strategist,
      config.harvester,
      config[TOKEN].address,
      vaultConfig.vault,
      vaultConfig.chainId,
      config.chainId,
      config.sgBridge,
      config.sgRouter,
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  console.log("done");
  await hopStrategy.waitForDeployment()

  console.log("HopStrategy deployed to:",await  hopStrategy.getAddress());
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {
    process.exitCode = 1;
  });
