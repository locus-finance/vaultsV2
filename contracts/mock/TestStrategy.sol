// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

contract TestStrategy is Initializable, BaseStrategy {
    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _router
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            _sgBridge,
            _router
        );
    }

    function name() external pure override returns (string memory) {
        return "TestStrategy";
    }

    function harvest() external override {}

    function estimatedTotalAssets() public pure override returns (uint256) {
        return 0;
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {}

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {}
}
