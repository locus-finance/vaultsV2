// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/// @title An interface that contains a functionality that is triggered once 1inch swap or quote
/// request has failed.
/// @author Locus Team
/// @notice The interface has to be implemented in any strategy that is to utilize 1inch 
/// swaps or quotes.
interface IBSEmergencySwapOrQuoteFacet {
    /// @notice Performs quote operation in another non-1inch price feed or oracle.
    /// @param src A token address that is going to be quoted.
    /// @param dst A token address that supposed to be received.
    /// @param amount An amount of `src` token.
    function emergencyRequestQuote(
        address src,
        address dst,
        uint256 amount
    ) external returns (uint256 amountOut);
    
    /// @notice Performs swap operation in another non-1inch AMM or CEX.
    /// @param src A token address that is going to be swapped.
    /// @param dst A token address that is going to be received.
    /// @param amount An amount of `src` token.
    /// @param slippage An amount of percents (1-100) to be allowed to lose.
    function emergencyRequestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;
}