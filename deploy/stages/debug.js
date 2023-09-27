const { emptyStage } = require('../fixtures/utils/helpers');
module.exports = emptyStage('Debug stage performed.');
module.exports.tags = ["debug"]; // UTILIZE ONLY AS FIXTURE OR HARDHAT EVM INITIAL DEPLOY SCRIPT
module.exports.dependencies = [
  "hop",
  "pearl",
  "pika",
  "updateTracerNames"
];
module.exports.runAtTheEnd = true;
