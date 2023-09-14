const { types } = require("hardhat/config");
module.exports = async function (taskArgs, hre) {
  (await hre.artifacts.getAllFullyQualifiedNames())
    .filter(
      e => {
        return !e.includes('hardhat') && 
          (e.startsWith('contracts') || taskArgs.areInternalContractsExcluded) &&
          (!e.includes('interface') || taskArgs.areInterfacesExcluded) &&
          (!e.includes('Mock') || taskArgs.areMocksExcluded);
      }
    );
}
