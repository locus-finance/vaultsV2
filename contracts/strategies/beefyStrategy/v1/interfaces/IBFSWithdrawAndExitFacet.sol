// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBFSWithdrawAndExitFacet {
    function exitPosition(uint256 _stakedAmount) external;
    function withdrawSome(uint256 _amountNeeded) external;
}