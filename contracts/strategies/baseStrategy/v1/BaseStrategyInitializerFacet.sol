// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IBaseStrategyInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";

contract BaseStrategyInitializerFacet is BaseFacet, IBaseStrategyInitializerFacet {
    function initialize() external override {
        InitializerLib.initialize();
    }
}