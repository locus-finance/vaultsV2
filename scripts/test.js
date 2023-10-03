// const { ethers } = require("ethers");

const lzRouterAbi = require("./LzRouter.json");

const factoryAbi = [
  "function getPool(address token1, address token2, uint24 fee) external view returns (address pool)",
];

const ABI = [
  "function poolId() external view returns (uint256)",
  "function symbol() external view returns (string memory)",
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

  const factory = await ethers.getContractAt(
    factoryAbi,
    "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  );
  console.log(
    await factory.getPool(
      "0x4200000000000000000000000000000000000006",
      "0x9a601c5bb360811d96a23689066af316a30c3027",
      10000
    )
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .then(() => { });
