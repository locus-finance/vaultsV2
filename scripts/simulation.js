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
  "function migrateStrategy(uint16,address,address) external",
  "function setVault(address,uint16) external",
  "function migrateMoney(address,address) external"
];


const vaultAddress = "0x2a889E9ef10c7Bd607473Aadc8c806c4511EB26f"
const hopStrategyAddress = "0xA93e1DfF89dcCCA3C3CadFd0A28aD071C230eD84"
const hopOwner = "0x942f39555D430eFB3230dD9e5b86939EFf185f0A"
const wantTokenAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"

const { vaultChain } = require("../utils");

const TOKEN = "USDC";

const dec6 = 1000000;
async function main() {
  const sigs = await ethers.getSigners();
  const provider = new ethers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  const saverStrategyAddress = await deployStrategy()
  await impersonateAccount(hopOwner)

  const hO = await ethers.provider.getSigner(
    hopOwner
  );

  await impersonateAccount("0x6318938F825F57d439B3a9E25C38F04EF97987D8")

  const vault = await ethers.provider.getSigner(
    "0x6318938F825F57d439B3a9E25C38F04EF97987D8"
  );

  const hop = await ethers.getContractAt(
    ABI,
    hopStrategyAddress
  );

  const saver = await ethers.getContractAt(
    ABI,
    saverStrategyAddress
  );

  const wanttoken = await ethers.getContractAt(
    ABI,
    wantTokenAddress
  );

  

  await sendFunds(await hO.getAddress())
  // console.log("ETA before migrate hop ",await hop.estimatedTotalAssets());
  // console.log("ETA before migrate saver ",await saver.estimatedTotalAssets());
  await hop.connect(hO).setVault(await sigs[0].getAddress(), 110)
  await saver.setVault(await sigs[0].getAddress(), 110)
  console.log("vaults setted");
  await hop.connect(sigs[0]).migrate(await saver.getAddress());
  console.log("migrated");
  console.log("moneyAfterr ",await wanttoken.balanceOf(await saver.getAddress()));
  console.log("EOA money before",await wanttoken.balanceOf(await sigs[0].getAddress()));
  await saver.connect(hO).migrateMoney(wantTokenAddress, sigs[0])
  console.log("EOA money after",await wanttoken.balanceOf(await sigs[0].getAddress()));

  //simulate dispatching
  // let addresses = []
  // let balances = []
  // for (let index = 0; index < 5; index++) {
  //   addresses.push(await sigs[index].getAddress())
  //   balances.push(ethers.parseUnits("10", 6))
  // }
  // console.log(addresses);
  // console.log(balances);
  

}



async function deployStrategy() {

    const sigs = await hre.ethers.getSigners();
  
    const config = bridgeConfig["arbitrumOne"];
    const vaultConfig = bridgeConfig[vaultChain("arbitrumOne")];
    const HopStrategy = await ethers.getContractFactory("SaverStrategy");
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
  
    console.log("Strategy deployed to:",await  hopStrategy.getAddress());
    return await  hopStrategy.getAddress();
  }

  async function sendFunds(to) {
    const sigs = await ethers.getSigners();
    const tx2 = await sigs[0].sendTransaction({
        to: to,
        value: ethers.parseEther("300"),
      });
      await tx2.wait();
      console.log("funds send");
  }


main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {
    process.exitCode = 1;
  });
