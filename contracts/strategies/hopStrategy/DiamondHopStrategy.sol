// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./v1/interfaces/IHopStrategyHarvestFaucet.sol";
import "./v1/interfaces/IHopStrategyStatsFaucet.sol";
import "./v1/interfaces/IHopStrategyInitializerFaucet.sol";

// IMPORTANT: all of the collective diamond interfaces MUST be prefixed with Diamond word.
/// @dev This MUST aggregate all of the faucets interfaces, to be able to grasp a full view of ABI in one place.
interface DiamondHopStrategy is
    IHopStrategyHarvestFaucet,
    IHopStrategyStatsFaucet,
    IHopStrategyInitializerFaucet
{}
