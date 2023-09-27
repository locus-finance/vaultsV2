// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../baseStrategy/v1/interfaces/IBSHarvestFacet.sol";
import "../baseStrategy/v1/interfaces/IBSLayerZeroFacet.sol";
import "../baseStrategy/v1/interfaces/IBSManagementFacet.sol";
import "../baseStrategy/v1/interfaces/IBSStargateFacet.sol";
import "../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";
import "../baseStrategy/v1/interfaces/IBSChainlinkFacet.sol";
import "../baseStrategy/v1/interfaces/IBSOneInchQuoteFacet.sol";
import "../baseStrategy/v1/interfaces/IBSOneInchSwapFacet.sol";

import "../baseStrategy/v1/interfaces/forSpecificStrategies/IBSAdjustPositionFacet.sol";
import "../baseStrategy/v1/interfaces/forSpecificStrategies/IBSEmergencySwapOrQuoteFacet.sol";
import "../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../baseStrategy/v1/interfaces/forSpecificStrategies/IBSPrepareMigrationFacet.sol";

import "./v1/interfaces/IHSStatsFacet.sol";
import "./v1/interfaces/IHSInitializerFacet.sol";
import "./v1/interfaces/IHSUtilsFacet.sol";
import "./v1/interfaces/IHSWithdrawAndExitFacet.sol";

/// @notice IMPORTANT: all of the collective diamond interfaces MUST be prefixed with "Diamond" word.
/// @dev This MUST aggregate all of the faucets interfaces, to be able to grasp a full view of ABI in one place.
interface DiamondHopStrategy is
    IBSHarvestFacet,
    IBSLayerZeroFacet,
    IBSManagementFacet,
    IBSStargateFacet,
    IBSSwapHelperFacet,
    IBSChainlinkFacet,
    IBSOneInchQuoteFacet,
    IBSOneInchSwapFacet,
    IBSAdjustPositionFacet,
    IBSEmergencySwapOrQuoteFacet,
    IBSLiquidatePositionFacet,
    IBSPrepareMigrationFacet,
    IBSQuoteNotifiableFacet,
    IHSUtilsFacet,
    IHSInitializerFacet,
    IHSStatsFacet,
    IHSWithdrawAndExitFacet
{}
