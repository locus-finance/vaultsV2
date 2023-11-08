// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IFactory {
    /// @dev Factory.get_n_coins(pool: address) → uint256[2]: view
    function get_n_coins(
        address pool
    ) external view returns (uint256[2] memory);

    /// @dev Factory.get_coins(pool: address) → address[2]: view
    function get_coins(address pool) external view returns (address[2] memory);
}
