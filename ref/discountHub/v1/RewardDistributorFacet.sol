// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../../interfaces/ISnacksPool.sol";
import "../interfaces/IDistributionChain.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/IStaking.sol";
import "./base/DHBaseFacet.sol";

contract RewardDistributorFacet is DHBaseFacet, IRewardDistributor {
    using SafeERC20 for IERC20;

    function _distributeReward(
        address who,
        address token,
        bool isCustodial
    ) internal {
        DHLib.Storage storage s = DHLib.get();
        uint256 rewardToDistribute = s.mappings.depositeeRewards[who][token];
        if (!isCustodial) {
            uint256 partForDistributionChain = (rewardToDistribute *
                s.primitives.distributionPartitionBasePoints) /
                DHLib.MAX_BASE_POINTS;
            IDistributionChain(address(this)).distributeToChain(
                token,
                partForDistributionChain
            );
            IERC20(token).safeTransfer(
                who,
                rewardToDistribute - partForDistributionChain
            );
        } else {
            IERC20(token).safeTransfer(who, rewardToDistribute);
        }
        s.mappings.acquiredTotalReward[token] -= rewardToDistribute;
    }

    function _distributeAllRewardsForSender(
        address sender,
        bool isCustodial
    ) internal {
        DHLib.Storage storage s = DHLib.get();
        ISnacksPool snacksPool = ISnacksPool(s.primitives.snacksPool);
        uint256 rewardTokensCount = snacksPool.getRewardTokensCount();
        for (uint256 i = 0; i < rewardTokensCount; i++) {
            _distributeReward(
                sender,
                snacksPool.getRewardToken(i),
                isCustodial
            );
        }
    }

    function setDistributionPartitionBasePoints(
        uint256 newBasePoints
    ) external override delegatedOnly onlyOwner {
        DHLib
            .get()
            .primitives
            .distributionPartitionBasePoints = newBasePoints;
    }

    function getReward() external override delegatedOnly {
        IStaking(address(this)).updateReward(msg.sender);
        _distributeAllRewardsForSender(msg.sender, false);
    }

    function getRewardForCustodial(address receiver) external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.AUTHORITY_ROLE);
        RolesManagementLib.enforceRole(receiver, RolesManagementLib.CUSTODIAL_MANAGER_ROLE);
        IStaking(address(this)).updateReward(address(this));
        _distributeAllRewardsForSender(receiver, true);
    }
}
