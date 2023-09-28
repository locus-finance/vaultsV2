// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title An interface that contains a functionality that is triggered once a strategy wants to liquidate
/// part of its position in an external protocol or to liquidate the position completely.
/// @author Locus Team
/// @notice The interface has to be implemented in any strategy that is to utilize base strategy facets.
interface IBSLiquidatePositionFacet {
    /// @notice Liquidates part of the strategys position in an external protocol.
    /// @param amount An amount of `want` tokens to be extracted from a position in an external protocol.
    /// @return _liquidatedAmount An amount of `want` token received from the external protocol.
    /// @return _loss An amount of `want` tokens that were lost during liquidation process in an external protocol.
    function liquidatePosition(
        uint256 amount
    ) external returns (uint256 _liquidatedAmount, uint256 _loss);

    /// @notice Liquidates whole position of the strategy in an external protocol.
    function liquidateAllPositions() external returns (uint256 _amountFreed);
}
