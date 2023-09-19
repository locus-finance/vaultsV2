// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSHarvestFacet {
    event StrategyReported(
        uint256 profit,
        uint256 loss,
        uint256 debtPayment,
        uint256 giveToStrategy,
        uint256 requestFromStrategy,
        uint256 creditAvailable,
        uint256 totalAssets
    );
}