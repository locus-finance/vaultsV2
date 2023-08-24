// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IPearlGaugeV2 {
    function balanceOf(address account) external view returns (uint256);

    function deposit(uint256 amount) external;

    function earned(address user) external view returns (uint256);

    function getReward() external;

    function withdraw(uint256 amount) external;

    function withdrawAll() external;

    function withdrawAllAndHarvest() external;
}
