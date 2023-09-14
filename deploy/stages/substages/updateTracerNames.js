const hre = require('hardhat');

module.exports = async ({
  getNamedAccounts,
  deployments
}) => {
  const { log } = deployments;
  const unpackedAccounts = await getNamedAccounts();
  log('Updating hardhat-tracer name tags...');
  const stack = [];
  const allNames = [];
  stack.push(hre.names);
  while (stack.length > 0) {
    const element = stack.pop();
    if ((typeof element) === 'string') {
      allNames.push(element);
      continue;
    }
    for (const subElement in element) {
      stack.push(element[subElement]);
    }
  }

  for (const name of allNames) {
    const deploymentOrNull = await deployments.getOrNull(name);
    if (deploymentOrNull != null && "address" in deploymentOrNull) {
      hre.tracer.nameTags[deploymentOrNull.address] = name;
    }
  }
  for (const name in unpackedAccounts) {
    hre.tracer.nameTags[unpackedAccounts[name]] = name; 
  }
  log(`Updated tags:\n${JSON.stringify(hre.tracer.nameTags)}`);
}
module.exports.tags = ["updateTracerNames"];
