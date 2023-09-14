// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../../interfaces/IZoinks.sol";
import "../../../interfaces/ISnacksMintRedeem.sol";
import "../../../interfaces/ISnacksPool.sol";
import "../interfaces/IStats.sol";
import "../interfaces/IStaking.sol";
import "./base/DHBaseFacet.sol";

contract StatsFacet is DHBaseFacet, IStats {
    function totalDeposit(
        address outputToken
    ) external view override delegatedOnly returns (uint256) {
        RolesManagementLib.enforceRole(
            outputToken,
            RolesManagementLib.ALLOWED_TOKEN_ROLE
        );
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 totalSnacksStaked = s.totalSnacksStaked;
        address snacksAddress = s.snacks;
        if (outputToken == snacksAddress) return totalSnacksStaked;
        if (outputToken == s.zoinks)
            return
                ISnacksMintRedeem(snacksAddress)
                    .calculatePayTokenAmountOnRedeem(totalSnacksStaked);
        revert BaseLib.InvalidAddress(outputToken);
    }

    function totalPoolReward(
        address rewardToken
    ) external view override delegatedOnly returns (uint256) {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        ISnacksPool snacksPool = ISnacksPool(s.snacksPool);
        uint256 rewardTokensCount = snacksPool.getRewardTokensCount();
        for (uint256 i = 0; i < rewardTokensCount; i++) {
            if (rewardToken == snacksPool.getRewardToken(i)) {
                return IStaking(address(this)).commonEarned(rewardToken);
            }
        }
        revert BaseLib.InvalidAddress(rewardToken);
    }
}
