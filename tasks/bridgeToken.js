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

    console.log(
        await sgBridge.poolIds(token.address, bridgeConfig[networkName].chainId)
    );
    console.log(
        await sgBridge.poolIds(
            token.address,
            bridgeConfig[destinationChain].chainId
        )
    );
    return;

    await token.approve(sgBridge.address, ethers.constants.MaxUint256);
    await sgBridge.bridge(
        token.address,
        utils.parseEther("10"),
        bridgeConfig[destinationChain].chainId,
        destinationAddr,
        "0x",
        {
            value: utils.parseEther("1"),
        }
    );
};
