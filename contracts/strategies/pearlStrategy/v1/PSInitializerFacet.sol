// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPSInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol";
import "../PSLib.sol";
import "../../baseStrategy/BSLib.sol";

contract PSInitializerFacet is BaseFacet, IPSInitializerFacet {
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

        strategyParams.want.approve(PSLib.UNISWAP_V3_ROUTER, type(uint256).max);
        strategyParams.want.approve(PSLib.PEARL_ROUTER, type(uint256).max);
        IERC20(PSLib.USDR).approve(PSLib.PEARL_ROUTER, type(uint256).max);
        IERC20(PSLib.USDC_USDR_LP).approve(
            PSLib.PEARL_GAUGE_V2,
            type(uint256).max
        );
        IERC20(PSLib.USDC_USDR_LP).approve(
            PSLib.PEARL_ROUTER,
            type(uint256).max
        );
        IERC20(PSLib.DAI).approve(PSLib.USDR_EXCHANGE, type(uint256).max);
        IERC20(PSLib.PEARL).approve(PSLib.PEARL_ROUTER, type(uint256).max);

        PSLib.get().adjustedTo1InchSlippage = uint8(
            (BSLib.get().p.slippage * 100) / BSLib.MAX_BPS
        );
    }
}
