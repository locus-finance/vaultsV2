// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSHarvestFacet {
    error DebtRatioNotZero();
    event StrategyReported(
        uint256 profit,
        uint256 loss,
        uint256 debtPayment,
        uint256 giveToStrategy,
        uint256 requestFromStrategy,
        uint256 creditAvailable,
        uint256 totalAssets
    );

    function harvest(
        uint256 _totalDebt,
        uint256 _debtOutstanding,
        uint256 _creditAvailable,
        uint256 _debtRatio,
        bytes memory _signature
    ) external;
}