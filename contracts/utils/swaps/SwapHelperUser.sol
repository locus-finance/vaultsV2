// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../../interfaces/IOraclizedSwapHelper.sol";

abstract contract SwapHelperUser {
    error SwapHelperOnly();
    
    event Notified(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );

    modifier onlySwapHelper() {
        if (msg.sender != address(swapHelper)) {
            revert SwapHelperOnly();
        }
        _;
    }

    IOraclizedSwapHelper public swapHelper;

    function notifyCallback(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external virtual onlySwapHelper {
        emit Notified(src, dst, amountOut, amountIn);
    }
}
