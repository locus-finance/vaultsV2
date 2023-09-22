// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IBSOneInchSwapFacet.sol";
import "./interfaces/IBSOneInchQuoteFacet.sol";
import "./interfaces/IBSSwapHelperFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSSwapHelperFacet is BaseFacet, IBSSwapHelperFacet {
    function quote(
        address src,
        address dst,
        uint256 amount
    ) external override {
        IBSOneInchQuoteFacet(address(this)).requestQuoteAndFulfillOnOracleExpense(
            src, dst, amount
        );
    }

    function swap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external override {
        IBSOneInchSwapFacet(address(this)).requestSwapAndFulfillOnOracleExpense(
            src, dst, amount, slippage
        );
    }
}