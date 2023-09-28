const hre = require('hardhat');

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

  const TOKEN = "USDC";

  await diamond.deploy('HopStrategy', {
    from: deployer,
    owner: deployer,
    facets: [
      "RolesManagementFacet",
      "BSHarvestFacet",
      "BSLayerZeroFacet",
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
      "HSWithdrawAndExitFacet"
    ],
    log: true,
    libraries: [
      'HSLib',
      'BSOneInchLib',
      'InitializerLib',
      'PausabilityLib',
      'RolesManagementLib'
    ],
    execute: {
      methodName: 'initialize',
      args: [
        [config.lzEndpoint],
        [
          deployer,
          config[TOKEN].address,
          vaultConfig.vault,
          vaultConfig.chainId,
          vaultConfig.chainId,
          config.slippage
        ],
        [
          config.sgBridge,
          config.sgRouter
        ],
        [
          140,
          1100,
          "0x1111111254EEB25477B68fb85Ed929f73A960582",
          "0x514910771AF9Ca656af840dff83E8264EcF986CA",
          "0x0168B5FcB54F662998B0620b9365Ae027192621f",
          "e11192612ceb48108b4f2730a9ddbea3",
          "0eb8d4b227f7486580b6f66706ac5d47",
        ]
      ]
    }
  });
}
module.exports.tags = ["hopStrategyDiamondDeploy", "hop"];
