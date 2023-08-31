// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/ISwapHelperSubscriber.sol";

contract MockSwapHelperSubscriber is ISwapHelperSubscriber {
    event Notified(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );

    function notify(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external override {
        emit Notified(src, dst, amountOut, amountIn);
    }
}