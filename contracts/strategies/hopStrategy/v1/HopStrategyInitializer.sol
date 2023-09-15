// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IHopStrategyInitializerFaucet.sol";
import "../../base/libraries/InitializerLib.sol";
import "../../base/facets/BaseFacet.sol";

contract HopStrategyInitializerFaucet is BaseFacet, IHopStrategyInitializerFaucet {
    function initialize() external override {
        InitializerLib.initialize();
    }
}