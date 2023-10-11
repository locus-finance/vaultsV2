// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISwapHelperSubscriber {
    function notify(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external;
}
