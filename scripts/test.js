const hre = require("hardhat");
const { ethers } = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");

const ABI = [
  "function estimatedTotalAssets() external view returns(uint256)",
  "function setManagementFee(uint256) external",
  "function swapUsdPlusToWant() external",
  "function balanceOf(address) external view returns(uint256)",
  "function adjustPosition(uint256)",
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
  // 108000000
  // 2400
  // 0xdeee509e572a298b176fb5180cc3d8df2748466ac671eee900691ccf74edefe437738a2741b6b328fcd29f9f759e5adff25726823e48d70a70c438faadfe7af41c

  // const impersonatedSigner = await ethers.getImpersonatedSigner(
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
  //   value: hre.ethers.utils.parseEther("5000"),
  // });
  // await tx2.wait();
  await upgradeVault();
  console.log("upgraded");
  const strategy = await ethers.getContractAt(
    ABI,
    "0xa5e7eB6391F34Ec9691A5d39E93A8b2336B7E717",
    wallet
  );

  const USDPLUS = await ethers.getContractAt(
    ABI,
    "0x73cb180bf0521828d8849bc8CF2B920918e23032",
    wallet
  );

  const USDC = await ethers.getContractAt(
    ABI,
    "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
    wallet
  );
  console.log(await USDPLUS.connect(wallet).balanceOf(strategy.address));
  console.log(await USDC.connect(wallet).balanceOf(strategy.address));
  console.log("----------------");
  console.log(await strategy.connect(wallet).swapUsdPlusToWant());

  console.log(await USDPLUS.connect(wallet).balanceOf(strategy.address));
  console.log(await USDC.connect(wallet).balanceOf(strategy.address));
  console.log("----------------");
  await strategy.connect(strategist).adjustPosition(0);

  console.log(await USDPLUS.connect(wallet).balanceOf(strategy.address));
  console.log(await USDC.connect(wallet).balanceOf(strategy.address));
  console.log("----------------");
}

async function upgradeVault() {
  const provider = new ethers.providers.JsonRpcProvider({
    url: "http://127.0.0.1:8545",
  });
  // const abiProxy = [
  //   "function transferOwnership(address) external",
  //   "function owner() external view returns(address)",
  // ];
  // const proxy = await hre.ethers.getContractAt(
  //   abiProxy,
  //   "0x4F202835B6E12B51ef6C4ac87d610c83E9830dD9"
  // );
  // console.log(await proxy.owner());
  console.log("upgrading");
  const owner = await hre.ethers.provider.getSigner(
    "0x6194738930D4239e596C1CC624Fb1cEa4ebE2665"
  );
  console.log(owner);
  console.log("upgrading");
  // await proxy
  //   .connect(owner)
  //   .transferOwnership("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  // console.log(await proxy.owner());
  const vault = await hre.ethers.getContractFactory("VelodromeStrategy", owner);
  console.log("upgrading");
  const upgraded = await hre.upgrades.upgradeProxy(
    "0xa5e7eB6391F34Ec9691A5d39E93A8b2336B7E717",
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
