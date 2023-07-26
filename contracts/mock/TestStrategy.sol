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

    function harvest() external override {
        uint256 wantBal = want.balanceOf(address(this));
        uint256 gain = wantBal / 100;
        (bool success, ) = address(want).call(
            abi.encodeWithSignature("mint(uint256)", gain)
        );
        require(success, "Investment failed");
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return want.balanceOf(address(this));
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 wantBal = want.balanceOf(address(this));
        _liquidatedAmount = (wantBal > _amountNeeded) ? _amountNeeded : wantBal;
        _loss = (_liquidatedAmount < _amountNeeded)
            ? _amountNeeded - _liquidatedAmount
            : 0;
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        return want.balanceOf(address(this));
    }
}
