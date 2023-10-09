// const { ethers } = require("ethers");

const lzRouterAbi = require("./LzRouter.json");
const ethers = require("ethers");
const hre = require("hardhat");
const bridgeConfig = require("../constants/bridgeConfig.json");

const factoryAbi = [
  "function getPool(address token1, address token2, uint24 fee) external view returns (address pool)",
];

const ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function symbol() external view returns (string memory)",
  "function withdraw() external",
  "function approve(address,uint256) external",
];

const ABI2 = ["function factory() external view returns (address)"];

const ABI3 = [
  "function hasStoredPayload(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool)",
];

async function main() {
  // const sgRouter = await ethers.getContractAt(
  //     ABI2,
  //     "0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f"
  // );
  // const factory = await ethers.getContractAt(
  //     FACTORY_ABI,
  //     await sgRouter.factory()
  // );
  // const k = await ethers.getContractAt(ABI, await factory.getPool(3));
  // console.log(await k.poolId(), await k.symbol());

  // const factory = await ethers.getContractAt(
  //   factoryAbi,
  //   "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  // );
  // console.log(
  //   await factory.getPool(
  //     "0x4200000000000000000000000000000000000006",
  //     "0x9a601c5bb360811d96a23689066af316a30c3027",
  //     10000
  //   )
  // );

  // Create a random mnemonic to use as the seed for the HDNode
  const mnemonic =
    "embark uncover mean anger scatter pill team fence energy harvest away topple";

  // Use the mnemonic to create an HDNode instance
  const localProvider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );

  const node = ethers.utils.HDNode.fromMnemonic(mnemonic);
  const vaultV1 = new ethers.Contract(
    "0x3edbE670D03C4A71367dedA78E73EA4f8d68F2E4",
    ABI,
    localProvider
  );
  // const factory = await ethers.getContractAt(
  //   ABI,
  //   "0x3edbE670D03C4A71367dedA78E73EA4f8d68F2E4"
  // );
  // Generate multiple wallets from the HDNode instance
  const wallets = [];
  const walletsPK = [];
  for (let i = 0; i < 20; i++) {
    const path = "m/44'/60'/0'/0/" + i;
    const wallet = node.derivePath(path);
    console.log(wallet.address);
    wallets.push(wallet.address);
    walletsPK.push(wallet.privateKey);
    console.log((await vaultV1.balanceOf(wallet.address)).toNumber());
  }
  // const { deployer } = await getNamedAccounts();

  // console.log(`Your address: ${deployer}. Network: ${hre.network.name}`);

  const config = bridgeConfig["optimism"];
  const Vault = await hre.ethers.getContractFactory("Vault");
  const TOKEN = "USDC";

  const vault = await upgrades.deployProxy(
    Vault,
    [
      wallets[0],
      config.lzEndpoint,
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      config.sgBridge,
      config.sgRouter,
    ],
    {
      initializer: "initialize",
      kind: "transparent",
    }
  );
  await vault.deployed();

  console.log("Vault deployed to:", vault.address);

  // new ethers.Wallet()
  const Migration = await hre.ethers.getContractFactory("Migration");
  const migration = await Migration.deploy(
    "0x3edbE670D03C4A71367dedA78E73EA4f8d68F2E4",
    vault.address,
    wallets
  );
  await migration.deployed();
  console.log("Migration deployed to:", migration.address);
  console.log(await migration.users(0));

  for (let index = 0; index < 10; index++) {
    const user = new ethers.Wallet(walletsPK[index], localProvider);
    await vaultV1
      .connect(user)
      .approve(migration.address, await vaultV1.balanceOf(user.address));
  }
  console.log("aaproved");
  await migration.withdraw({ gasLimit: 10000000 });
  console.log("Withdrawed");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => {});
