// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBSInitializerFacet {
    struct LayerZeroParams {
        address lzEndpoint;
    }
    
    struct StrategyParams {
        address strategist;
        IERC20 want;
        address vault;
        uint16 vaultChainId;
        uint16 currentChainId;
        uint256 slippage;
    }

    struct StargateParams {
        address sgBridge;
        address sgRouter;
    }

    struct ChainlinkParams {
        uint256 quoteJobFee;
        uint256 swapCalldataJobFee; 
        address aggregationRouter;
        address chainlinkTokenAddress;
        address chainlinkOracleAddress;
        string swapCalldataJobId; 
        string quoteJobId;
    }

    function __BaseStrategy_init(
        LayerZeroParams calldata layerZeroParams,
        StrategyParams calldata strategyParams,
        StargateParams calldata stargateParams,
        ChainlinkParams calldata chainlinkParams
    ) external;
}
