// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IVaultFeeReward {
    function getClaimableReward(
        address account
    ) external view returns (uint256);

    function claimReward(address user) external;

    function reinvest() external;
}
