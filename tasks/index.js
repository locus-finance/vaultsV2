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
    "estimateSwap",
    "Estimate swap price in LINK tokens for a given calldata. WARNING: COULD ONLY BY UTILIZED IF THE REQUEST ON THE SWAP IS ONCHAIN. SO IT IS RECOMMENDED TO EMBED THIS TASK INTO SOME KIND OF A SERVER JOB WITH SUBSCRIPTION ON PLACING REQUESTS.",
    require("./estimateSwapOn1inch")
)
    .addParam("swapCalldata", "A string of swap calldata bytes")
    .addParam(
        "swapHelperAddress", 
        "An address of the 1inch Aggregation Protocol swap sender (SwapHelper.sol)"
        )
    .addParam("gasPrice", "A current gas price on the network of the router")
    .addParam("priceUSDtoLINK", "A current price of the LINK in USD in wei")
    .addParam("priceETHtoUSD", "A current price of the ETH in USD in wei")
    .addParam("safetyBuffer", "A float multiplier of the output price in LINK (ex. 1.5)")
    .addParam("value", "An amount of native currency if it is required by the calldata (swapCalldata), if none required: specify 0");

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
