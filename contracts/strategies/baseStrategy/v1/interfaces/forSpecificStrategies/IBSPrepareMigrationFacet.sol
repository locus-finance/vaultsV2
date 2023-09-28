// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title An interface that contains a functionality that is triggered once the position of the 
/// strategy has to move to another strategy.
/// @author Locus Team
/// @notice The interface has to be implemented in any strategy that is to utilize base strategy facets.
interface IBSPrepareMigrationFacet {
    /// @notice Prepares position to be moved to new strategy at address `newStrategy`.
    /// @param newStrategy An address of new strategy contract.
    function prepareMigration(address newStrategy) external;
}