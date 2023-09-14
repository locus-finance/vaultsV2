const hre = require('hardhat');

module.exports = async ({
  getNamedAccounts,
  deployments
}) => {
  const { diamond } = deployments;
  const { deployer } = await getNamedAccounts();
  await diamond.deploy('DiscountHub', {
    from: deployer,
    owner: deployer,
    facets: [
      "HopStrategyHarvestFaucet",
      "HopStrategyStatsFaucet"
    ],
    log: true,
    libraries: [
      'HPLib',
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
