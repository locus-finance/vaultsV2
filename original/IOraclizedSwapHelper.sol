// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import "./ISwapHelper.sol";

// interface IOraclizedSwapHelper is ISwapHelper {
//     function fulfillSwap() external;

//     function fulfillQuote() external;

//     function requestQuoteAndFulfillOnOracleExpense(
//         address src,
//         address dst,
//         uint256 amount
//     ) external;

//     function requestSwapAndFulfillOnOracleExpense(
//         address src,
//         address dst,
//         uint256 amount,
//         uint8 slippage
//     ) external payable;

//     function quoteBuffer() external view returns(
//         SwapInfo memory,
//         uint256 outAmount
//     );

//     function swapBuffer() external view returns(
//         address srcToken,
//         address dstToken,
//         uint256 inAmount
//     );
// }