// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IHopStrategyInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";

contract HopStrategyInitializerFacet is BaseFacet, IHopStrategyInitializerFacet {
    function initialize() external override {
        InitializerLib.initialize();
    }
}