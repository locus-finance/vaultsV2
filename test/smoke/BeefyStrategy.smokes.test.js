const { expect } = require("chai");
const hre = require("hardhat");

describe("BeefyStrategy (estimatedTotalAssets() call)", () => {
  const mintNativeTokens = async (signer, amountHex) => {
    await hre.network.provider.send("hardhat_setBalance", [
      signer.address || signer,
      amountHex,
    ]);
  };
  const withImpersonatedSigner = async (signerAddress, action) => {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [signerAddress],
    });

    const impersonatedSigner = await hre.ethers.getSigner(signerAddress);
    await action(impersonatedSigner);

    await hre.network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [signerAddress],
    });
  };

  xit("should perform calculate a total assets", async () => {
    // const TargetContract = await hre.ethers.getContractFactory("BeefyStrategy");

    // // await hre.upgrades.forceImport(TARGET_ADDRESS, TargetContract);

    // await hre.upgrades.upgradeProxy(
    //   "0x13bf88e6d5105f7935C0A8F88d7e87716e9Bb535",
    //   TargetContract
    // );
    
    const beefyStrategyInstance = await hre.ethers.getContractAt(
      "BeefyStrategy",
      "0x13bf88e6d5105f7935C0A8F88d7e87716e9Bb535" //"0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3"
    );
    console.log((await beefyStrategyInstance.estimatedTotalAssets()).toString());
  });

  it("should perform adjust position", async () => {
    const TargetContract = await hre.ethers.getContractFactory("BeefyStrategy");

    // await hre.upgrades.forceImport(TARGET_ADDRESS, TargetContract);

    await hre.upgrades.upgradeProxy(
      "0x13bf88e6d5105f7935C0A8F88d7e87716e9Bb535",
      TargetContract
    );
    const beefyStrategyInstance = await hre.ethers.getContractAt(
      "BeefyStrategy",
      "0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3", // "0x13bf88e6d5105f7935C0A8F88d7e87716e9Bb535"
    );
    const strategist = await beefyStrategyInstance.strategist();
    await withImpersonatedSigner(strategist, async (strategistSigner) => {
      await beefyStrategyInstance.connect(strategistSigner).adjustPosition(
        hre.ethers.constants.Zero
      );
    });
  });
});
