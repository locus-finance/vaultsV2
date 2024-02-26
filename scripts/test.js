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

  await impersonateAccount("0x3c2792d5ea8f9c03e8e73738e9ed157aeb4fecbe")

  const governance = await ethers.provider.getSigner(
    "0x3c2792d5ea8f9c03e8e73738e9ed157aeb4fecbe"
  );
  // await upgradeVault()

  const tx2 = await sigs[0].sendTransaction({
    to: await governance.getAddress(),
    value: ethers.parseEther("300"),
  });
  await tx2.wait();
  console.log("funds send");
  const strategy = await ethers.getContractAt(
    ABI,
    "0xC4E7d7c15b8F5c2D77512460b84802D1D3693692"
  );

  

  // const vault = await ethers.getContractAt(
  //   ABI,
  //   "0x2a889E9ef10c7Bd607473Aadc8c806c4511EB26f"
  // );
  // await mine(1000);
  // await time.increase(1000)
  // console.log(await vault.owner())
  // console.log(await strategy.connect(governance).estimatedTotalAssets());
  console.log(await strategy.connect(governance).harvest(0,0,138062884,10,"0x5c2a93f96c989ada694ef361d822b10a2ea4cb9bda57a1182524fa975bde887e1c30c563b4d75992773b0db2966ae2710c42c9ccbe8a0bfd574a8551059f823c1b", { gasLimit: 30000000 }));
  console.log(await strategy.connect(governance).estimatedTotalAssets());
  // console.log(await newStrategy.connect(governance).estimatedTotalAssets());
}

async function upgradeVault() {
  const provider = new ethers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  await impersonateAccount("0xD44044f706B7a3491ae810173e916cE94a15ade5")

  // console.log("upgrading");
  const owner = await ethers.provider.getSigner(
    "0xD44044f706B7a3491ae810173e916cE94a15ade5"
  );
  // await proxy
  //   .connect(owner)
  //   .transferOwnership("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  // console.log(await proxy.owner());
  const vault = await hre.ethers.getContractFactory("HopStrategy", owner);
  console.log("upgrading");
  const upgraded = await hre.upgrades.upgradeProxy(
    "0x68Ee86f798f247FeC4d33C224Dad360dC919450A",
    vault
  );
  console.log("upgrading");
  console.log("Successfully upgraded implementation of", await upgraded.getAddress());
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
