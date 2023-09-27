// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSQuoteNotifiableFacet {
    function notifyCallback(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external;
}
