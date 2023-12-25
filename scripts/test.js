const hre = require("hardhat");
const { ethers } = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");
const {
  impersonateAccount
} = require("@nomicfoundation/hardhat-network-helpers");
const ABI = [
  "function estimatedTotalAssets() external view returns(uint256)",
  "function setManagementFee(uint256) external",
  "function swapUsdPlusToWant() external",
  "function balanceOf(address) external view returns(uint256)",
  "function adjustPosition(uint256)",
  "function harvest(uint256,uint256,uint256,uint256,bytes) external"
];

async function main() {
  const sigs = await hre.ethers.getSigners();
  console.log("123");
  const provider = new ethers.providers.JsonRpcProvider({
    url: "http://127.0.0.1:8545",
  });
  console.log(1);
  // console.log(
  //   "BALANCE: ",
  //   await provider.getBalance("0xf712eE1C45C84aEC0bfA1581f34B9dc9a54D7e60")
  // );

  // console.log(await provider.getBalance(sigs[0].address));
  await impersonateAccount("0x27f52fd2E60B1153CBD00D465F97C05245D22B82")
  // const impersonatedSigner = await hre.ethers.getImpersonatedSigner(
  //   "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  // );

  const strategist = await ethers.provider.getSigner(
    "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  );

  const wallet = await ethers.provider.getSigner(
    "0x6194738930D4239e596C1CC624Fb1cEa4ebE2665"
  );
  console.log(wallet._address);
  // const tx2 = await sigs[0].sendTransaction({
  //   to: wallet._address,
  //   value: hre.ethers.utils.parseEther("3000"),
  // });
  // await tx2.wait();
  // await upgradeVault();
  // console.log("upgraded");
  const strategy = await ethers.getContractAt(
    ABI,
    "0x205D6195fa2ebFE04CDa0be91365c43aA9e1b739"
  );
  
  console.log(await strategy.connect(strategist).estimatedTotalAssets({gasLimit : 30000000}))
  console.log(await strategy.connect(strategist).harvest(56250899402, 0, 8549771736, 4500, "0xbf5ea603cc33a00e58ebddadf391c6c3008cf3250a3edc753cb88030c6673192407dd8201ef819bb8235cdbb295c0b3172c8268be83153d238c2539efe1498531b",{gasLimit : 30000000}));
}

async function upgradeVault() {
  const provider = new ethers.providers.JsonRpcProvider({
    url: "http://127.0.0.1:8545",
  });
  await impersonateAccount("0x6194738930D4239e596C1CC624Fb1cEa4ebE2665")

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

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {
    process.exitCode = 1;
  });
