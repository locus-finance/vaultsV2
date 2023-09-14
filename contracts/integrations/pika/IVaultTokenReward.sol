// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IVaultTokenReward {
    function earned(address account) external view returns (uint256);

    function getReward() external;
}
