// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../base/libraries/InitializerLib.sol";
import "../interfaces/IInitializer.sol";
import "./base/DHBaseFacet.sol";

contract InitializerFacet is IInitializer, DHBaseFacet {
    function initialize(
        uint256 distributionPartitionBasePoints,
        address[] calldata innerContracts, // avoid stack too deep
        address[] calldata entities,
        bytes32[] calldata roles,
        address[] calldata distributionChainReceivers,
        uint256[] calldata distributionChainReceiversShares
    ) public override {
        InitializerLib.initialize();
        // You cannot use other facets here, because the contract instance that would be called could not have the other facets deployed yet, so
        // to not unnecessary limit the deployment order of facets, this would perform
        // regardless of any deployment order of the facets.
        if (entities.length != roles.length) {
            revert BaseLib.UnequalLengths(entities.length, roles.length);
        }
        if (
            distributionChainReceivers.length !=
            distributionChainReceiversShares.length
        ) {
            revert BaseLib.UnequalLengths(
                distributionChainReceivers.length,
                distributionChainReceiversShares.length
            );
        }
        RolesManagementLib.grantRole(
            address(this),
            RolesManagementLib.INITIALIZER_ROLE
        );
        for (uint256 i = 0; i < entities.length; i++) {
            RolesManagementLib.grantRole(entities[i], roles[i]);
        }
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        s.distributionPartitionBasePoints = distributionPartitionBasePoints;
        s.zoinks = innerContracts[0];
        s.snacks = innerContracts[1];
        s.snacksPool = innerContracts[2];
        s.depositeeBlocklist = innerContracts[3];
        for (uint256 i = 0; i < distributionChainReceivers.length; i++) {
            s.receivers.push(
                DHLib.Receiver({
                    previousShare: 0,
                    share: distributionChainReceiversShares[i],
                    receiver: distributionChainReceivers[i],
                    isBlocked: false
                })
            );
            s.sumOfShares += distributionChainReceiversShares[i];
        }
    }

    function reinitialize(
        uint256 distributionPartitionBasePoints,
        address[] calldata innerContracts, // avoid stack too deep
        address[] calldata entities,
        bytes32[] calldata roles,
        address[] calldata distributionChainReceivers,
        uint256[] calldata distributionChainReceiversShares
    ) external override delegatedOnly onlyOwner {
        InitializerLib.reset();
        initialize(
            distributionPartitionBasePoints,
            innerContracts, // avoid stack too deep
            entities,
            roles,
            distributionChainReceivers,
            distributionChainReceiversShares
        );
    }

    function getStorage()
        external
        view
        override
        returns (DHLib.StoragePrimitives memory r)
    {
        r = DHLib.get().primitives;
    }

    function getSnacksDepositOf(
        address who
    ) external view override returns (uint256) {
        return DHLib.get().mappings.snacksDepositOf[who];
    }

    function getRewardPerTokenStored(
        address token
    ) external view override returns (uint256) {
        return DHLib.get().mappings.rewardPerTokenStored[token];
    }

    function getDepositeeRewardPerTokenPaid(
        address who,
        address token
    ) external view override returns (uint256) {
        return DHLib.get().mappings.depositeeRewardPerTokenPaid[who][token];
    }

    function getDepositeeRewards(
        address who,
        address token
    ) external view override returns (uint256) {
        return DHLib.get().mappings.depositeeRewards[who][token];
    }

    function getAcquiredTotalReward(
        address token
    ) external view override returns (uint256) {
        return DHLib.get().mappings.acquiredTotalReward[token];
    }

    function getUnprocessedTokens(
        address who,
        address token
    ) external view override returns (uint256) {
        return DHLib.get().mappings.unprocessedTokens[who][token];
    }
}
