// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IHSInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol";
import "../HSLib.sol";

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
        IERC20(HSLib.LP).approve(HSLib.STAKING_REWARD, type(uint256).max);
        IERC20(HSLib.LP).approve(HSLib.HOP_ROUTER, type(uint256).max);
        IERC20(HSLib.HOP).approve(HSLib.UNISWAP_V3_ROUTER, type(uint256).max);
        strategyParams.want.approve(HSLib.HOP_ROUTER, type(uint256).max);
    }
}