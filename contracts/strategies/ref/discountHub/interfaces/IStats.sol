// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IStats {
    function totalDeposit(address outputToken) external view returns (uint256);

    function totalPoolReward(address rewardToken) external view returns (uint256);
}
