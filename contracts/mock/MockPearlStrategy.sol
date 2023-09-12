// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {SwapHelperDTO} from "../utils/SwapHelperUser.sol";
import {PearlStrategy} from "../strategies/PearlStrategy.sol";

import "../strategies/utils/PearlStrategyLib.sol";

contract MockPearlStrategy is PearlStrategy {
    function sellUsdr(uint256 _usdrAmount) external {
        PearlStrategyLib.sellUsdr(
            _usdrAmount,
            address(want),
            wantDecimals,
            _swapHelperDTO,
            _swapEventEmitter,
            __innerWithSlippage
        );
    }

    function sellPearl(uint256 _pearlAmount) external {
        PearlStrategyLib.sellPearl(
            _pearlAmount,
            address(want),
            wantDecimals,
            _swapHelperDTO,
            _swapEventEmitter,
            __innerWithSlippage
        );
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
