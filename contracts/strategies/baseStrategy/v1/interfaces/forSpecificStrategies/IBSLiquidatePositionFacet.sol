// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSLiquidatePositionFacet {
    function liquidatePosition(
        uint256 amount
    ) external returns (uint256 _liquidatedAmount, uint256 _loss);

    function liquidateAllPositions() external returns (uint256 _amountFreed);
}
