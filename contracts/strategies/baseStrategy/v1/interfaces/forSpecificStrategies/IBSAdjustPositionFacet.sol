// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title An interface to be implemented in a specific strategy.
/// @author Locus Finance
/// @notice It is a functional interface.
interface IBSAdjustPositionFacet {
    /// @notice Adjusts a position of the strategy in its vault according to the business logic
    /// of the strategy.
    /// @param debtOutstanding An amount of `want` tokens in debt to a vault.
    function adjustPosition(uint256 debtOutstanding) external;
}