// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISwapHelper {
    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external;
    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;
    function fulfillSwap() external;
    function fulfillQuote() external;
}