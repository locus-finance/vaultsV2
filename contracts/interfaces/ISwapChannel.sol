// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISwapChannel {
    function notifySwap(uint256 amount) external;
    function setCurrentSlippage(uint256 _newSlippage) external;
}
