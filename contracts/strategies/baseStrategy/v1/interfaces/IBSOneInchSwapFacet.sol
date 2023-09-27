// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSOneInchSwapFacet {
    function setMaxAllowancesIfNeededAndCheckPayment(
        address src,
        uint256 amount,
        address sender
    ) external payable;

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;

    function requestSwapAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;

    function fulfillSwapRequest() external;

    function fulfillSwap() external;

    function strategistFulfillSwap(
        bytes memory _swapCalldata
    ) external payable;
}
