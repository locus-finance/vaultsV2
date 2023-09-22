// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISgBridge} from "../../../interfaces/ISgBridge.sol";
import {IStargateRouter} from "../../../integrations/stargate/IStargate.sol";

import "./interfaces/IBSLayerZeroFacet.sol";
import "./interfaces/IBSInitializerFacet.sol";
import "./interfaces/IBSChainlinkFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../diamondBase/libraries/RolesManagementLib.sol";
import "../BSLib.sol";

contract BSInitializerFacet is BaseFacet, IBSInitializerFacet {
    function __BaseStrategy_init(
        LayerZeroParams calldata layerZeroParams,
        StrategyParams calldata strategyParams,
        StargateParams calldata stargateParams,
        ChainlinkParams calldata chainlinkParams
    ) external override internalOnly {
        BSLib.Primitives storage p = BSLib.get().p;

        IBSLayerZeroFacet(address(this))._initialize(layerZeroParams.lzEndpoint);
        IBSChainlinkFacet(address(this))._initialize(
            chainlinkParams.quoteJobFee,
            chainlinkParams.swapCalldataJobFee,
            chainlinkParams.aggregationRouter,
            chainlinkParams.chainlinkTokenAddress,
            chainlinkParams.chainlinkOracleAddress,
            chainlinkParams.swapCalldataJobId,
            chainlinkParams.quoteJobId
        );

        p.strategist = strategyParams.strategist;
        RolesManagementLib.grantRole(strategyParams.strategist, RolesManagementLib.STRATEGIST_ROLE);
        RolesManagementLib.grantRole(msg.sender, RolesManagementLib.OWNER_ROLE);
        
        p.want = strategyParams.want;
        p.vaultChainId = strategyParams.vaultChainId;
        p.vault = strategyParams.vault;
        p.slippage = strategyParams.slippage;
        p.wantDecimals = IERC20Metadata(address(strategyParams.want)).decimals();
        p.signNonce = 0;
        p.currentChainId = strategyParams.currentChainId;
        p.sgBridge = ISgBridge(stargateParams.sgBridge);
        p.sgRouter = IStargateRouter(stargateParams.sgRouter);

        p.want.approve(stargateParams.sgBridge, type(uint256).max);
    }
}