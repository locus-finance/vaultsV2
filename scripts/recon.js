const hre = require("hardhat");

const FACTORY_ABI = [
    "function getPool(uint256 value) external view returns (address)",
];

const ABI = [
    "function poolId() external view returns (uint256)",
    "function symbol() external view returns (string memory)",
];

const ABI2 = ["function factory() external view returns (address)"];

async function main() {
    const sgRouter = await ethers.getContractAt(
        ABI2,
        "0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f"
    );
    const factory = await ethers.getContractAt(
        FACTORY_ABI,
        await sgRouter.factory()
    );
    const k = await ethers.getContractAt(ABI, await factory.getPool(3));
    console.log(await k.poolId(), await k.symbol());
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .then(() => {});
