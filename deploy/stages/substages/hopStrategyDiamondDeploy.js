const hre = require('hardhat');
const { manipulateFacet } = require('../../fixtures/utils/helpers');

module.exports = async ({
  getNamedAccounts,
  deployments
}) => {
  const { diamond } = deployments;
  const { deployer } = await getNamedAccounts();

  const bridgeConfig = require("../../../constants/bridgeConfig.json");
  const { vaultChain } = require("../../../utils");
  const config = bridgeConfig["arbitrumOne"];
  const vaultConfig = bridgeConfig[vaultChain("arbitrumOne")];

  // TO BE UTILIZED AS PARAMETER TO THE STAGE IF NECESSARY
  // const ethereumMainnetChainLinkParams = [
  //   140,
  //   1100,
  //   "0x1111111254EEB25477B68fb85Ed929f73A960582",
  //   "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  //   "0x0168B5FcB54F662998B0620b9365Ae027192621f",
  //   "e11192612ceb48108b4f2730a9ddbea3",
  //   "0eb8d4b227f7486580b6f66706ac5d47",
  // ];

  const arbitrumMainnetChainLinkParams = [
    100,
    200,
    "0x1111111254EEB25477B68fb85Ed929f73A960582",
    "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4",
    "0xD8edDB284d25DbbC5189E488639D689DFE7AaB49",
    "e11192612ceb48108b4f2730a9ddbea3",
    "0eb8d4b227f7486580b6f66706ac5d47",
  ];

  const execute = {
    methodName: 'initialize',
    args: [
      [config.lzEndpoint],
      [
        deployer,
        config["USDC"].address,
        vaultConfig.vault,
        vaultConfig.chainId,
        vaultConfig.chainId,
        config.slippage
      ],
      [
        config.sgBridge,
        config.sgRouter
      ],
      arbitrumMainnetChainLinkParams
    ]
  };

  const facets = [
    "RolesManagementFacet",
    "BSHarvestFacet",
    "BSManagementFacet",
    "BSStargateFacet",
    "BSSwapHelperFacet",
    "BSUtilsFacet",
    "HSAdjustPositionFacet",
    "HSEmergencySwapOrQuoteFacet",
    "HSInitializerFacet",
    "HSLiquidatePositionFacet",
    "HSPrepareMigrationFacet",
    "HSStatsFacet",
    "HSUtilsFacet",
    "HSWithdrawAndExitFacet",
    "BSLayerZeroFacet"
  ];

  const libraries = [
    'HSLib',
    'BSOneInchLib',
    'InitializerLib',
    'PausabilityLib',
    'RolesManagementLib'
  ];

  await diamond.deploy('HopStrategy', {
    from: deployer,
    facets,
    log: true,
    libraries,
    execute
  });

  await manipulateFacet(
    hre.names.internal.diamonds.hopStrategy,
    2, // FacetCutAction.Remove == 2
    deployments,
    require('hardhat-deploy/extendedArtifacts/OwnershipFacet.json').abi
  );
}
module.exports.tags = ["hopStrategyDiamondDeploy", "hop"];
