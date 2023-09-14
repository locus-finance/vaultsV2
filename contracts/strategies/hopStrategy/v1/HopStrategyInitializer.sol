// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IHopStrategyInitializerFaucet.sol";

import "../../base/libraries/InitializerLib.sol";

contract HopStrategyInitializerFaucet is IHopStrategyInitializerFaucet {
    function initialize() external override {
        InitializerLib.initialize();
    }
}