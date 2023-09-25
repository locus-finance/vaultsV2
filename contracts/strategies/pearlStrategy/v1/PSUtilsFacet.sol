// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "../PSLib.sol";

contract PSUtilsFacet is BaseFacet, IPSUtilsFacet {
    function claimAndSellRewards() external override internalOnly {
    }

    function notifyCallback(
        address,
        address,
        uint256 amountOut,
        uint256
    ) external override internalOnly {
    }
}