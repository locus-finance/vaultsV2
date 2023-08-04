// const { ethers } = require("ethers");

const lzRouterAbi = require("./LzRouter.json");

const FACTORY_ABI = [
    "function getPool(uint256 value) external view returns (address)",
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

    const lzEndpoint = await ethers.getContractAt(
        lzRouterAbi,
        "0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1"
    );
    console.log(await lzEndpoint.chainId());
    console.log(
        await lzEndpoint.storedPayload(
            10109,
            "0xAFC820a62BFA831022641995118Bac750Dafec05E8Bb4dD0d74ff6F32992C5f0B7C85617A24e3D6E"
        )
    );
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .then(() => {});
