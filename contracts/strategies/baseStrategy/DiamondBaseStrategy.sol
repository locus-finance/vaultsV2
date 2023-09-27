// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./v1/interfaces/IBSHarvestFacet.sol";
import "./v1/interfaces/IBSStatsFacet.sol";
import "./v1/interfaces/IBSInitializerFacet.sol";
import "./v1/interfaces/IBSLayerZeroFacet.sol";
import "./v1/interfaces/IBSManagementFacet.sol";
import "./v1/interfaces/IBSStargateFacet.sol";
import "./v1/interfaces/IBSUtilsFacet.sol";
import "./v1/interfaces/IBSSwapHelperFacet.sol";
import "./v1/interfaces/IBSChainlinkFacet.sol";
import "./v1/interfaces/IBSOneInchQuoteFacet.sol";
import "./v1/interfaces/IBSOneInchSwapFacet.sol";
import "./v1/interfaces/IBSQuoteNotifiableFacet.sol";

/// @notice IMPORTANT: all of the collective diamond interfaces MUST be prefixed with Diamond word.
/// @dev This MUST aggregate all of the faucets interfaces, to be able to grasp a full view of ABI in one place.
interface DiamondBaseStrategy is
    IBSHarvestFacet,
    IBSStatsFacet,
    IBSInitializerFacet,
    IBSLayerZeroFacet,
    IBSManagementFacet,
    IBSStargateFacet,
    IBSUtilsFacet,
    IBSSwapHelperFacet,
    IBSChainlinkFacet,
    IBSOneInchQuoteFacet,
    IBSOneInchSwapFacet,
    IBSQuoteNotifiableFacet
{}
