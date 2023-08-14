// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IPikaPerpV4 {
    struct Stake {
        // 32 bytes
        address owner; // 20 bytes
        uint96 amount; // 12 bytes
        // 32 bytes
        uint128 shares; // 16 bytes
        uint128 timestamp; // 16 bytes
    }

    function getStake(address stakeOwner) external view returns (Stake memory);

    function redeem(address user, uint256 shares, address receiver) external;

    function stake(uint256 amount, address user) external;
}
