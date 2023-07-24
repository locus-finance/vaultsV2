const { utils } = require("ethers");

const bridgeConfig = require("../constants/bridgeConfig.json");

const TOKEN = "USDC";
const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";

module.exports = async function (taskArgs, hre) {
    const { destinationAddr, destinationChain } = taskArgs;
    const networkName = hre.network.name;
    const SgBridge = await ethers.getContractFactory("SgBridge");
    const sgBridge = await SgBridge.attach(bridgeConfig[networkName].sgBridge);

    const token = await ethers.getContractAt(
        IERC20_SOURCE,
        bridgeConfig[networkName][TOKEN].address
    );

    await token
        .approve(sgBridge.address, ethers.constants.MaxUint256)
        .then((tx) => tx.wait());

    const startgateRouter = await ethers.getContractAt(
        "IStargateRouter",
        bridgeConfig[networkName].sgRouter
    );
    const dstGasForCall = await sgBridge.dstGasForCall();
    const [feeWei] = await startgateRouter.quoteLayerZeroFee(
        bridgeConfig[destinationChain].chainId,
        /* functionType= */ 1,
        destinationAddr,
        "0x",
        {
            dstGasForCall,
            dstNativeAmount: 0,
            dstNativeAddr: sgBridge.address,
        }
    );

    await sgBridge
        .bridgeProxy(
            token.address,
            utils.parseEther("10"),
            bridgeConfig[destinationChain].chainId,
            destinationAddr,
            "0x",
            {
                value: feeWei.mul(3),
            }
        )
        .then((tx) => tx.wait());
};
