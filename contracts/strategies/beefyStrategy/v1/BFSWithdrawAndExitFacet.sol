// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IBFSStatsFacet.sol";
import "./interfaces/IBFSUtilsFacet.sol";
import "./interfaces/IBFSWithdrawAndExitFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../BFSLib.sol";

contract BFSWithdrawAndExitFacet is BaseFacet, IBFSWithdrawAndExitFacet {
    function withdrawSome(uint256 _amountNeeded) external override internalOnly {
    }

    function exitPosition(uint256 _stakedAmount) public internalOnly override {
    }
}