// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface ITokenPostProcessor {
    event Delayed(address indexed token, uint256 indexed amount);
    function postProcessDeposit(
        address sender,
        address tokenIn,
        uint256 amountIn
    ) external returns (uint256 amountOut);
    function postProcessWithdraw(
        address sender,
        address tokenIn,
        uint256 amountIn
    ) external returns (uint256 amountOut);
}