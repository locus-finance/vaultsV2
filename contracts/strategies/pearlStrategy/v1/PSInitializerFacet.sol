// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPSInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol";
import "../PSLib.sol";

contract PSInitializerFacet is BaseFacet, IPSInitializerFacet {
    function initialize(
        IBSInitializerFacet.LayerZeroParams calldata layerZeroParams,
        IBSInitializerFacet.StrategyParams calldata strategyParams,
        IBSInitializerFacet.StargateParams calldata stargateParams,
        IBSInitializerFacet.ChainlinkParams calldata chainlinkParams
    ) external override {
        InitializerLib.initialize();
    }
}