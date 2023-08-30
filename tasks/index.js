task(
    "configureBridge",
    "Configures SgBrdige on target chain",
    require("./configureBridge")
);

task(
    "bridgeToken",
    "Bridges token from one chain to another",
    require("./bridgeToken")
)
    .addParam(
        "destinationAddr",
        "Address of the recipient on the destination chain"
    )
    .addParam("destinationChain", "Destination chain");

task(
    "upgrade",
    "Upgrades a contract to a new implementation",
    require("./upgrade")
)
    .addParam("targetContract", "Name of the contract to upgrade")
    .addParam("targetAddr", "Address of the contract to upgrade");

task(
    "calculateLZFee",
    "Calculates the Layer Zero fee",
    require("./calculateLZFee")
);

task(
    "signHarvest",
    "Signs harvest date on behalf of the strategist",
    require("./signHarvest")
);

task(
    "strategyInfo",
    "Gets information about strategy for harvest",
    require("./strategyInfo")
).addParam("strategyChain", "Chain name where strategy resides");
