const axios = require("axios");
const diamondCutFacetAbi = require('hardhat-deploy/extendedArtifacts/DiamondCutFacet.json').abi;

////////////////////////////////////////////
// Constants Starts
////////////////////////////////////////////

const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";
const skipIfAlreadyDeployed = true;

////////////////////////////////////////////
// Constants Ends
////////////////////////////////////////////

const mintNativeTokens = async (signer, amountHex) => {
  await hre.network.provider.send("hardhat_setBalance", [
    signer.address || signer,
    amountHex
  ]);
}

const getFakeDeployment = async (address, name, save) => {
  await save(name, {address});
}

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
}

const getEventBody = async (eventName, contractInstance, resultIndex=-1) => {
  const filter = contractInstance.filters[eventName]();
  const filterQueryResult = await contractInstance.queryFilter(filter);
  const lastIndex = filterQueryResult.length == 0 ? 0 : filterQueryResult.length - 1;
  return filterQueryResult[resultIndex == -1 ? lastIndex : resultIndex].args;
}

const sendLinkFromWhale = async (toAddress, linkAmount) => {
  const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  const LINK_WHALE = "0xF977814e90dA44bFA03b6295A0616a897441aceC";
  const linkInstance = await hre.ethers.getContractAt("IERC20", LINK_ADDRESS);
  await withImpersonatedSigner(LINK_WHALE, async (linkWhaleSigner) => {
      await mintNativeTokens(LINK_WHALE, "0x100000000000000000");
      await linkInstance.connect(linkWhaleSigner).transfer(toAddress, linkAmount);
  });
}

const getOracleQuote = async (getEnv, src, dst, amount) => {
  let rawResult;
  try {
      rawResult = await axios({
          method: "get",
          url: 'https://api.1inch.dev/swap/v5.2/1/quote',
          headers: {
              "accept": "application/json",
              "Authorization": `Bearer ${getEnv("ONE_INCH_API_KEY")}`
          },
          params: {src, dst, amount},
          responseType: 'json'
      });
  } catch (error) {
      console.log(error);
  }
  return rawResult.data.toAmount;
}

const getOracleSwapCalldata = async (getEnv, src, dst, from, amount, slippage, receiver, disableEstimate=true) => {
  let rawResult;
  try {
      rawResult = await axios({
          method: "get",
          url: 'https://api.1inch.dev/swap/v5.2/1/swap',
          headers: {
              "accept": "application/json",
              "Authorization": `Bearer ${getEnv("ONE_INCH_API_KEY")}`
          },
          params: {src, dst, amount, slippage, from, receiver, disableEstimate},
          responseType: 'json'
      });
  } catch (error) {
      console.log(error);
  }
  return rawResult.data.tx.data;
}

const emptyStage = (message) => 
  async ({deployments}) => {
      const {log} = deployments;
      log(message);
  };

const diamondCut = async (
  facetCuts, 
  initializableContract, 
  initializeCalldata, 
  diamondInstanceName, 
  deployments
) => {
  const diamondInstance = await hre.ethers.getContractAt(
    diamondCutFacetAbi,
    (await deployments.get(diamondInstanceName.proxy)).address
  );

  await diamondInstance.diamondCut(
    facetCuts,
    initializableContract,
    initializeCalldata
  );
}

const manipulateFacet = async (
  diamondInstanceName, 
  facetCutAction,
  deployments, 
  abi,
  facetNameOrFacetAddress=hre.ethers.constants.AddressZero,
  initializableContract=hre.ethers.constants.AddressZero,
  initializeCalldata=hre.ethers.utils.stripZeros(hre.ethers.utils.arrayify("0x00"))
) => {
  const facetAddress = facetNameOrFacetAddress.startsWith("0x") 
    ? facetNameOrFacetAddress 
    : (await deployments.get(facetName)).address;

  const iface = new hre.ethers.utils.Interface(abi);
  const functions = Object.values(iface.functions);

  const formatType = hre.ethers.utils.FormatTypes.full;
  deployments.log(`Manipulating ABI at ${diamondInstanceName.interface} (FacetCutAction: ${facetCutAction}): \n${functions.reduce((a, b) => `\t${a.format(formatType)}\n\t${b.format(formatType)}`)}`);

  await diamondCut(
    [
      [
        facetAddress,
        facetCutAction,
        functions.map(e => iface.getSighash(e))
      ]
    ],
    initializableContract,
    initializeCalldata,
    diamondInstanceName,
    deployments
  );
}

module.exports = {
  skipIfAlreadyDeployed,
  withImpersonatedSigner,
  mintNativeTokens,
  getFakeDeployment,
  DEAD_ADDRESS,
  getEventBody,
  sendLinkFromWhale,
  getOracleSwapCalldata,
  getOracleQuote,
  emptyStage,
  diamondCut,
  manipulateFacet
};
