// const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai");

const {
  impersonateAccount, mine, time
} = require("@nomicfoundation/hardhat-network-helpers");
require("dotenv").config();
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

const holders = require("../config/xUsdHolders.json")
// import holders from "../config/xUsdHolders.json";
const { vaultChain } = require("../utils");

const TOKEN = "USDC";
const vaultTokenAddr = "0x95611DCBFfC93b97Baa9C65A23AAfDEc088b7f32"
const totalSupply = 139092814073

const dec6 = 1000000;
async function main() {
    const vaultToken = await ethers.getContractAt(
        ABI,
        vaultTokenAddr
      );
  const sigs = await ethers.getSigners();
  const provider = new ethers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  const sender = (new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY)).connect(provider);
  console.log(await sender.getAddress());
  const holdersLen = holders.length;
  let sumToSpread = 0;
  let addresses = []
  let balances = []
  console.log("Detected ", holdersLen, " amount of users to send tokens");
    for (let index = 0; index < holdersLen; index++) {
        holders[index].Balance *= dec6
        sumToSpread += holders[index].Balance;
        addresses.push(holders[index].HolderAddress)
        balances.push(holders[index].Balance)
    }
    console.log("Sum to spread: ", sumToSpread);
    console.log("Total supply:",totalSupply )
    console.log("Sender has: ", await vaultToken.balanceOf(await sender.getAddress()));
    expect(await vaultToken.balanceOf(await sender.getAddress())).to.gte(sumToSpread)
    await vaultToken.connect(sender).dispatch(addresses, balances);

  
}



main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {
    process.exitCode = 1;
  });

//Step 1: deploy new vault and new strategies and whole system and test it
//Step 2: deploy Saver Strategy and add it to old vault(test)
//Step 3: change vault address on hop and on saver to EOA, and call migrate from this address
//Step 4: call adjust position on saver and do the same on beefy tp unload all money
//Step 5: deposit all money into new vault
//Step 6: Call dispatch function on vaultToken contract to spread new token among users

