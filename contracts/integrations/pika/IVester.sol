// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IVester {
    function initialDepositedAll(
        address _account
    ) external view returns (uint256 initialDepositedAllAmount);
}
