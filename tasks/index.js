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
