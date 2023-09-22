// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSOneInchQuoteFacet {
    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external returns (uint256);

    /// @notice Fulfills logic that depends on quote operation regardless if an Oracle responded or not.
    /// @dev Utilized in a variant when quote request is fulfilled either by a strategist or on an Oracle expenses.
    function fulfillQuoteRequest() external;

    /// @notice Fulfills logic that depends on quote operation if an Oracle has already provided information.
    function fulfillQuote() external;

    /// @notice Doing both: register quote operation in the storage and executes the logic that depends on in.
    /// And both on an Oracle expense.
    function requestQuoteAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount
    ) external;

    function strategistFulfillQuote(
        uint256 toAmount
    ) external;
}
