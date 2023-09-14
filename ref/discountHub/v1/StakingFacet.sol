// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../../interfaces/ISnacksPool.sol";
import "../interfaces/IStaking.sol";
import "./base/DHBaseFacet.sol";

contract StakingFacet is DHBaseFacet, IStaking {
    using SafeERC20 for IERC20;

    function commonStake(uint256 amount) external internalOnly override {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        address snacksPoolAddress = s.snacksPool;
        ISnacksPool snacksPool = ISnacksPool(snacksPoolAddress);
        IERC20 snacksInstance = IERC20(s.snacks);
        if (snacksInstance.allowance(address(this), snacksPoolAddress) < amount) {
            snacksInstance.approve(snacksPoolAddress, type(uint256).max);
        }
        snacksPool.stake(amount);
        if (!snacksPool.isLunchBoxParticipant(address(this))) {
            snacksPool.activateLunchBox();
            emit CommonStakerActivatedLunchBox();
        }
        emit CommonStake(amount);
    }

    function commonWithdraw(uint256 amount) external internalOnly override {
        ISnacksPool(DHLib.get().primitives.snacksPool).withdraw(amount);
        emit CommonWithdraw(amount);
    }

    function commonEarned(address rewardToken) public delegatedOnly view override returns (uint256) {
        DHLib.Storage storage s = DHLib.get();
        ISnacksPool snacksPool = ISnacksPool(s.primitives.snacksPool);
        return snacksPool.earned(address(this), rewardToken) + s.mappings.acquiredTotalReward[rewardToken];
    }

    function updateReward(address account) external internalOnly override {
        ISnacksPool snacksPool = ISnacksPool(DHLib.get().primitives.snacksPool);
        uint256 rewardTokensCount = snacksPool.getRewardTokensCount();
        for (uint256 i = 0; i < rewardTokensCount; i++) {
            address token = snacksPool.getRewardToken(i);
            uint256 newRewardPerTokenStored = rewardPerToken(token);
            DHLib.StorageMappings storage sm = DHLib.get().mappings;
            sm.rewardPerTokenStored[token] = newRewardPerTokenStored;
            uint256 earnedAmount = earned(token, account);
            sm.depositeeRewards[account][token] = earnedAmount;
            sm.depositeeRewardPerTokenPaid[account][token] = newRewardPerTokenStored;
            emit CommonUpdateReward(token, account, earnedAmount);
        }
    } 

    function rewardPerToken(address rewardToken) public view override returns (uint256) {
        DHLib.Storage storage s = DHLib.get();
        uint256 rewardPerTokenStored = s.mappings.rewardPerTokenStored[rewardToken];
        uint256 totalDeposit = s.primitives.totalSnacksStaked; 
        if (totalDeposit == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + commonEarned(rewardToken) * DHLib.PRECISION / totalDeposit;
    }
    
    function earned(address token, address account) public view returns (uint256) {
        DHLib.StorageMappings storage s = DHLib.get().mappings;
        return s.snacksDepositOf[account]
            * (rewardPerToken(token) - s.depositeeRewardPerTokenPaid[account][token]) 
            / DHLib.PRECISION 
            + s.depositeeRewards[account][token];
    }

    function notifyRewardAmount() external delegatedOnly override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.AUTHORITY_ROLE);
        DHLib.Storage storage s = DHLib.get();
        ISnacksPool snacksPool = ISnacksPool(s.primitives.snacksPool);
        uint256 rewardTokensCount = snacksPool.getRewardTokensCount();
        
        // calculation of earned tokens total
        uint256[] memory oldBalances = new uint256[](rewardTokensCount);
        address[] memory tokens = new address[](rewardTokensCount);
        for (uint256 i = 0; i < rewardTokensCount; i++) {
            tokens[i] = snacksPool.getRewardToken(i);
            oldBalances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
        snacksPool.getReward();
        for (uint256 i = 0; i < rewardTokensCount; i++) {
            uint256 rewardAccounted = IERC20(tokens[i]).balanceOf(address(this)) 
                - oldBalances[i];
            s.mappings.acquiredTotalReward[tokens[i]] += rewardAccounted;
            emit RewardAccounted(rewardAccounted, tokens[i]); 
        }
    }
}
