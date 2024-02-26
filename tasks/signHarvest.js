const bridgeConfig = require("../constants/bridgeConfig.json");
// require("@nomicfoundation/hardhat-toolbox");
// require("hardhat/config");

// module.exports = async function (taskArgs, hre) {
//     const { addr } = taskArgs.addr;
//     console.log(addr);
    // const [signer] = await ethers.getSigners();
    // const networkName = hre.network.name;

    // const strategy = await ethers.getContractAt(
    //     "BaseStrategy",
    //     bridgeConfig[networkName].TestStrategy
    // );

    // console.log(`Signing by ${signer.address}`);

    // const signPayload = await strategy.strategistSignMessageHash();
    // console.log(`Sign payload ${signPayload}`);
    // const signature = await signer.signMessage(
    //     ethers.utils.arrayify(signPayload)
    // );

    // console.log("Signature", signature);
// };

// task("signHarvest", "A")
//   .addPositionalParam("addr")
//   .setAction(async (taskArgs) => {
//     console.log(taskArgs);
//   });