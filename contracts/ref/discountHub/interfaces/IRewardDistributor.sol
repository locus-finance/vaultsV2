// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IRewardDistributor {
    function setDistributionPartitionBasePoints(uint256 newBasePoints) external;
    function getReward() external;
    function getRewardForCustodial(address receiver) external; // back
}
