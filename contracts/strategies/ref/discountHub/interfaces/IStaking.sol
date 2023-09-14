// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IStaking {
    event RewardAccounted(uint256 indexed amount, address indexed token);
    event CommonStakerActivatedLunchBox();
    event CommonStake(uint256 indexed amount);
    event CommonWithdraw(uint256 indexed amount);
    event CommonUpdateReward(address indexed token, address indexed who, uint256 indexed earnedAmount);

    function commonStake(uint256 amount) external;

    function commonWithdraw(uint256 amount) external;
    
    function commonEarned(address rewardToken) external view returns (uint256);

    function updateReward(address account) external;

    function rewardPerToken(address rewardToken) external view returns (uint256);

    function earned(address token, address account) external view returns (uint256);

    function notifyRewardAmount() external; // once per 12 by backend
}
