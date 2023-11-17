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

  it("should perform calculate a total assets", async () => {
    const factory = await hre.ethers.getContractAt(
      "IFactory",
      "0x1764ee18e8b3cca4787249ceb249356192594585"
    );
    const beefyStrategyInstance = await hre.ethers.getContractAt(
      "BeefyStrategy",
      "0xD6D7673D94BAcDD1FA3D67D38B5A643Ba24F85b3"
    );
    console.log(await factory.get_coins("0xAA3b055186f96dD29d0c2A17710d280Bc54290c7"));
    console.log((await beefyStrategyInstance.estimatedTotalAssets()).toString());
  });
});
