// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IPSWithdrawAndExitFacet {
    function exitPosition(uint256 _stakedAmount) external;
    function withdrawSome(uint256 _amountNeeded) external;
}