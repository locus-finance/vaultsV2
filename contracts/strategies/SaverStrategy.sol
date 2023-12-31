// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {BaseStrategy} from "../BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../integrations/hop/IStakingRewards.sol";
import "../integrations/hop/IRouter.sol";

contract SaverStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    address public saver;

    function initialize(
        address _saver,
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _router
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            _currentChainId,
            _sgBridge,
            _router,
            9800
        );
        saver = _saver;
        want.approve(_saver, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "SaverStrategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return 0;
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        want.safeTransfer(saver, want.balanceOf(address(this)));
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        
    }

    function _prepareMigration(address _newStrategy) internal override {
    }
}
