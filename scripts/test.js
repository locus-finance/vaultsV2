const hre = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");

const ABI = ["function setStargatePoolId(address,uint16,uint256) external"];

async function main() {
  // const sigs = await hre.ethers.getSigners();
  // const provider = new hre.ethers.providers.JsonRpcProvider(
  //   "http://127.0.0.1:8545"
  // );
  // // console.log(sigs[0].address);
  // console.log(
  //   "BALANCE: ",
  //   await provider.getBalance("0xf712eE1C45C84aEC0bfA1581f34B9dc9a54D7e60")
  // );
  // const tx = await sigs[0].sendTransaction({
  //   to: "0x27f52fd2E60B1153CBD00D465F97C05245D22B82",
  //   value: hre.ethers.utils.parseEther("1000"),
  // });
  // console.log(await provider.getBalance(sigs[0].address));
  // 108000000
  // 2400
  // 0xdeee509e572a298b176fb5180cc3d8df2748466ac671eee900691ccf74edefe437738a2741b6b328fcd29f9f759e5adff25726823e48d70a70c438faadfe7af41c
  // const signer = await hre.ethers.provider.getSigner(
  //   "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  // );
  // const impersonatedSigner = await ethers.getImpersonatedSigner(
  //   "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  // );
  // await upgradeVault();
  // const signer1 = await network.provider.request({
  //   method: "hardhat_impersonateAccount",
  //   params: ["0x27f52fd2E60B1153CBD00D465F97C05245D22B82"],
  // });
  // console.log(signer1.address);
  // const impersonatedSigner = await ethers.getImpersonatedSigner(
  //   "0x27f52fd2E60B1153CBD00D465F97C05245D22B82"
  // );
  // console.log(await signer.address());
  // const node = ethers.utils.HDNode.fromMnemonic(mnemonic);
  const provider = new hre.ethers.providers.JsonRpcProvider(
    "https://arb1.arbitrum.io/rpc"
  );
  console.log((await provider.getNetwork()).chainId);
  let wallet = await new ethers.Wallet(
    process.env.DEPLOYER_PRIVATE_KEY
  ).connect(provider);
  const targetContract = await hre.ethers.getContractAt(
    ABI,
    "0x4575603b0b15ae956bce755312fdcec655f4f019",
    wallet
  );

  await targetContract.setStargatePoolId(
    "0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA",
    184,
    1
  );
  // console.log(await targetContract.connect(signer).name());
  // const tx1 = await targetContract
  //   .connect(impersonatedSigner)
  //   .harvest(
  //     0,
  //     0,
  //     108000000,
  //     2400,
  //     "0xdeee509e572a298b176fb5180cc3d8df2748466ac671eee900691ccf74edefe437738a2741b6b328fcd29f9f759e5adff25726823e48d70a70c438faadfe7af41c",
  //     { gasLimit: 30000000 }
  //   );
  // console.log(tx1);
  // const factory = await ethers.getContractAt(
  //   ABI,
  //   "0x3edbE670D03C4A71367dedA78E73EA4f8d68F2E4"
  // );
  // await hre.run("verify:verify", {
  //   address: "0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3",
  // });
}

async function upgradeVault() {
  // const abiProxy = [
  //   "function transferOwnership(address) external",
  //   "function owner() external view returns(address)",
  // ];
  // const proxy = await hre.ethers.getContractAt(
  //   abiProxy,
  //   "0x4F202835B6E12B51ef6C4ac87d610c83E9830dD9"
  // );
  // console.log(await proxy.owner());
  // const owner = await ethers.getImpersonatedSigner(
  //   "0x729F2222aaCD99619B8B660b412baE9fCEa3d90F"
  // );
  // await proxy
  //   .connect(owner)
  //   .transferOwnership("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  // console.log(await proxy.owner());
  const vault = await hre.ethers.getContractFactory("OnChainVault");
  const upgraded = await hre.upgrades.upgradeProxy(
    "0x0f094f6deb056af1fa1299168188fd8c78542a07",
    vault
  );
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
