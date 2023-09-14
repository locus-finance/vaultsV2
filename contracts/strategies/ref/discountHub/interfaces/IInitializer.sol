// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../DHLib.sol";

interface IInitializer {
    function initialize(
        uint256 distributionPartitionBasePoints,
        address[] calldata innerContracts, // avoid stack too deep
        address[] calldata people, 
        bytes32[] calldata roles,
        address[] calldata distributionChainReceivers,
        uint256[] calldata distributionChainReceiversShares
    ) external;
    function reinitialize(
        uint256 distributionPartitionBasePoints,
        address[] calldata innerContracts, // avoid stack too deep
        address[] calldata entities,
        bytes32[] calldata roles,
        address[] calldata distributionChainReceivers,
        uint256[] calldata distributionChainReceiversShares
    ) external;
    function getStorage() external view returns (DHLib.StoragePrimitives memory);
    function getSnacksDepositOf(address who) external view returns (uint256);
    function getRewardPerTokenStored(address token) external view returns (uint256);
    function getDepositeeRewardPerTokenPaid(address who, address token) external view returns (uint256);
    function getDepositeeRewards(address who, address token) external view returns (uint256);
    function getAcquiredTotalReward(address token) external view returns (uint256);
    function getUnprocessedTokens(address who, address token) external view returns (uint256);
}