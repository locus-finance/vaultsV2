// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../PSLib.sol";
import "./interfaces/IPSWithdrawAndExitFacet.sol";
import "./interfaces/IPSStatsFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";

contract PSLiquidatePositionFacet is BaseFacet, IBSLiquidatePositionFacet {
    function liquidatePosition(
        uint256 _amountNeeded
    )
        external
        override
        internalOnly
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
    }

    function liquidateAllPositions()
        external
        internalOnly
        override
        returns (uint256 _amountFreed)
    {
    }
}
