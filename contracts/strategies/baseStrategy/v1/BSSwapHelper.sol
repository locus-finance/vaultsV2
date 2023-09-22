// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IBSSwapHelperFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSSwapHelperFacet is BaseFacet, IBSSwapHelperFacet {
    function quote(
        address src,
        address dst,
        uint256 amount
    ) external override {
        
    }

    function swap(
        address src,
        address dst,
        uint256 amount,
        uint256 slippage
    ) external override {

    }
}