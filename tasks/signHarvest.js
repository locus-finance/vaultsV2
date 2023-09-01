const bridgeConfig = require("../constants/bridgeConfig.json");

module.exports = async function (taskArgs, hre) {
    const [signer] = await ethers.getSigners();
    const networkName = hre.network.name;

    const strategy = await ethers.getContractAt(
        "BaseStrategy",
        bridgeConfig[networkName].TestStrategy
    );

    console.log(`Signing by ${signer.address}`);

    const signPayload = await strategy.strategistSignMessageHash();
    console.log(`Sign payload ${signPayload}`);
    const signature = await signer.signMessage(
        ethers.utils.arrayify(signPayload)
    );

    console.log("Signature", signature);
};
