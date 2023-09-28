const hre = require('hardhat');

module.exports = async ({
  getNamedAccounts,
  deployments
}) => {
  const { diamond } = deployments;
  const { deployer } = await getNamedAccounts();
  await diamond.deploy('HopStrategy', {
    from: deployer,
    owner: deployer,
    facets: [
      "BSHarvestFacet",
      "BSLayerZeroFacet",
      "BSManagementFacet",
      "BSStargateFacet",
      "BSSwapHelperFacet",
      "BSUtilsFacet",
      "HSAdjustPositionFacet",
      "HSEmergencySwapOrQuoteFacet",
      "HSInitializerFacet",
      "HSLiquidatePOsitionFacet",
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

      ]
    }
  });
}
module.exports.tags = ["hopStrategyDiamondDeploy", "hop"];
