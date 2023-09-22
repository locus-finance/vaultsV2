// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol";
import "./interfaces/IHSInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol" ;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HSInitializerFacet is BaseFacet, IHSInitializerFacet {
    function initialize(
        IBSInitializerFacet.LayerZeroParams calldata layerZeroParams,
        IBSInitializerFacet.StrategyParams calldata strategyParams,
        IBSInitializerFacet.StargateParams calldata stargateParams,
        IBSInitializerFacet.ChainlinkParams calldata chainlinkParams
    ) external override {
        InitializerLib.initialize();
        IBSInitializerFacet(address(this)).__BaseStrategy_init(
            layerZeroParams,
            strategyParams,
            stargateParams,
            chainlinkParams
        );
        // IERC20(LP).approve(STAKING_REWARD, type(uint256).max);
        // IERC20(LP).approve(HOP_ROUTER, type(uint256).max);
        // IERC20(HOP).approve(UNISWAP_V3_ROUTER, type(uint256).max);
        // want.approve(HOP_ROUTER, type(uint256).max);
    }
}