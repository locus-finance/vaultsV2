// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../utils/SwapHelperUser.sol";

contract MockSwapHelperSubscriber is SwapHelperUser {
    event MockNotified(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );

    function notifyCallback(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external override {
        emit MockNotified(src, dst, amountOut, amountIn);
    }
}