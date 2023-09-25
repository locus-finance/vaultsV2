// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSAdjustPositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../PSLib.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "./interfaces/IPSStatsFacet.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

contract PSAdjustPositionFacet is BaseFacet, IBSAdjustPositionFacet {
    function adjustPosition(
        uint256 _debtOutstanding
    ) external override internalOnly {
        
    }
}
