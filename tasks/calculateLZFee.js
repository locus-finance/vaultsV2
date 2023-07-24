const lzNetworks = require("../constants/networks.json");
const { utils } = require("ethers");

const DESTINATION_ADDR = "0x8637f8AFe33f98eEEfDfD32D0eB52b28d16a05fA";
const DST_GAS_FOR_CALL = 500_000;
const PAYLOAD_LENGTH = 128;

const ESTIMATE_CHAINS = ["polygon", "optimism", "arbitrum", "mainnet"];

module.exports = async function (taskArgs, hre) {
    for (const targetChain of ESTIMATE_CHAINS) {
        if (targetChain === hre.network.name) {
            continue;
        }

        const networkName = hre.network.name;

        const startgateRouter = await ethers.getContractAt(
            "IStargateRouter",
            lzNetworks[networkName].sgRouter
        );
        const [feeWei] = await startgateRouter.quoteLayerZeroFee(
            lzNetworks[targetChain].chainId,
            /* functionType= */ 1,
            DESTINATION_ADDR,
            "0x" + "FF".repeat(PAYLOAD_LENGTH),
            {
                dstGasForCall: DST_GAS_FOR_CALL,
                dstNativeAmount: 0,
                dstNativeAddr: DESTINATION_ADDR,
            }
        );

        console.log(
            `Stargate fee for ${networkName} to ${targetChain}: ${utils
                .formatEther(feeWei)
                .substring(0, 7)} ETH`
        );

        const lzEndpoint = await ethers.getContractAt(
            "ILayerZeroEndpointUpgradeable",
            lzNetworks[networkName].lzEndpoint
        );
        const [lzFee] = await lzEndpoint.estimateFees(
            lzNetworks[targetChain].chainId,
            DESTINATION_ADDR,
            "0x" + "FF".repeat(PAYLOAD_LENGTH),
            false,
            utils.solidityPack(["uint16", "uint256"], [1, DST_GAS_FOR_CALL])
        );
        console.log(
            `LZ fee for ${networkName} to ${targetChain}: ${utils
                .formatEther(lzFee)
                .substring(0, 7)} ETH`
        );

        console.log();
    }
};
