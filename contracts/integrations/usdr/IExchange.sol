// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IExchange {
    function scaleFromUnderlying(
        uint256 amount
    ) external view returns (uint256);

    function scaleToUnderlying(uint256 amount) external view returns (uint256);

    function swapFromUnderlying(
        uint256 amountIn,
        address to
    ) external returns (uint256 amountOut);

    function updateMintingStats(int128[7] calldata delta) external;
}
