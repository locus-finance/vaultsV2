// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IBFSUtilsFacet.sol";
import "../BFSLib.sol";

contract BFSUtilsFacet is BaseFacet, IBFSUtilsFacet {
}