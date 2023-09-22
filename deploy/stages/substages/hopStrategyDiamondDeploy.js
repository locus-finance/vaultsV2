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
      "HSHarvestFaucet",
      "HSStatsFaucet",
      "HSInitializerFaucet"
    ],
    log: true,
    libraries: [
      'HSLib',
      'BaseLib',
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
