// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IBSEmergencySwapOrQuoteFacet {
    function emergencyRequestQuote(
        address src,
        address dst,
        uint256 amount
    ) external returns (uint256 amountOut);
    
    function emergencyRequestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;
}