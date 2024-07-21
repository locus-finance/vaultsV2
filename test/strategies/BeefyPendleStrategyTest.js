const { expect } = require("chai");
const { utils } = require("ethers");
const hre = require("hardhat");
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;

describe("BeefyPendleStrategy", function () {
  let deployer;

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

  beforeEach(async function () {
    await deployments.fixture(["MockSwapHelperSubscriber", "SwapHelper"]);
    const accounts = await getNamedAccounts();
    deployer = accounts.deployer;
  });

  it('should', async () => {

  });
});
