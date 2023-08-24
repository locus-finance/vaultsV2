// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {PearlStrategy} from "../strategies/PearlStrategy.sol";

abstract contract MockPearlStrategy is PearlStrategy {
    function sellUsdr(uint256 _usdrAmount) external {
        _sellUsdr(_usdrAmount);
    }

    function sellPearl(uint256 _pearlAmount) external {
        _sellPearl(_pearlAmount);
    }

    function withdrawSome(uint256 _amountNeeded) external {
        _withdrawSome(_amountNeeded);
    }

    function exitPosition(uint256 _stakedLpTokens) external {
        _exitPosition(_stakedLpTokens);
    }

    function liquidatePosition(uint256 _amountNeeded) external {
        _liquidatePosition(_amountNeeded);
    }

    function liquidateAllPositions() external returns (uint256) {
        return _liquidateAllPositions();
    }
}
