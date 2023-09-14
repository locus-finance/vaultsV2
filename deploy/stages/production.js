const { emptyStage } = require('../fixtures/utils/helpers');
module.exports = emptyStage('Production stage performed.');
module.exports.tags = ["production"];
module.exports.dependencies = [
  // TODO Make the production sequence.
  "updateTracerNames"
];
module.exports.runAtTheEnd = true;
