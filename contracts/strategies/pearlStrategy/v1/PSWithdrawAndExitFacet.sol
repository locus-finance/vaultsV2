// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "./interfaces/IPSStatsFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "./interfaces/IPSWithdrawAndExitFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../PSLib.sol";

contract PSWithdrawAndExitFacet is BaseFacet, IPSWithdrawAndExitFacet {
    function withdrawSome(uint256 _amountNeeded) external override internalOnly {
    }

    function exitPosition(uint256 _stakedAmount) public internalOnly override {
    }
}