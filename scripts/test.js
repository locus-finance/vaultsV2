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
  await impersonateAccount("0x3C2792d5Ea8f9C03e8E73738E9Ed157aeB4FeCBe")
  // const impersonatedSigner = await hre.ethers.getImpersonatedSigner(
  //   "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  // );

  const strategist = await ethers.provider.getSigner(
    "0x3C2792d5Ea8f9C03e8E73738E9Ed157aeB4FeCBe"
  );

  // const wallet = await ethers.provider.getSigner(
  //   "0x6194738930D4239e596C1CC624Fb1cEa4ebE2665"
  // );
  // console.log(wallet._address);
  // const tx2 = await sigs[0].sendTransaction({
  //   to: wallet._address,
  //   value: hre.ethers.utils.parseEther("3000"),
  // });
  // await tx2.wait();
  // await upgradeVault();
  // console.log("upgraded");
  const strategy = await ethers.getContractAt(
    ABI,
    "0xA93e1DfF89dcCCA3C3CadFd0A28aD071C230eD84"
  );

  console.log(await strategy.connect(strategist).harvest(0, 0, 13500000, 4500, "0x8143be837ea4cc68a285877b2319a5f02f3fac6f3585e9a670ec14936984f1196bc75ddbdb75b2a38bd4857e66eb87cbb35a51cf139859a08b31a997ae6dd3711c", { gasLimit: 30000000 }));
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

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {
    process.exitCode = 1;
  });
