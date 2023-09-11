// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "../integrations/hop/IStakingRewards.sol";
import "../integrations/hop/IRouter.sol";
import "./utils/HopStrategyLib.sol";
import "../utils/SwapHelperUser.sol";

contract HopStrategy is
    Initializable,
    BaseStrategy,
    SwapHelperUser
{
    using SafeERC20 for IERC20;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _sgRouter,
        uint256 _slippage
    ) external initializer {
        // __AccessControl_init();
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            uint16(block.chainid),
            _sgBridge,
            _sgRouter,
            _slippage
        );
        IERC20(HopStrategyLib.LP).safeApprove(
            HopStrategyLib.STAKING_REWARD,
            type(uint256).max
        );
        IERC20(HopStrategyLib.LP).safeApprove(
            HopStrategyLib.HOP_ROUTER,
            type(uint256).max
        );
        IERC20(HopStrategyLib.HOP).safeApprove(
            HopStrategyLib.UNISWAP_V3_ROUTER,
            type(uint256).max
        );
        want.safeApprove(HopStrategyLib.HOP_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "HopStrategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        if (!_swapHelperDTO.isQuoteBufferContainsHopToWantValue) {
            revert HopStrategyLib.InitializeQuoteBufferWithHopToWantValue();
        }
        return HopStrategyLib.lpToWant(balanceOfStaked(), address(this)) + balanceOfWant() + _swapHelperDTO.quoteBuffer;
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        _claimAndSellRewards();
        uint256 unstakedBalance = balanceOfWant();

        uint256 excessWant;
        if (unstakedBalance > _debtOutstanding) {
            excessWant = unstakedBalance - _debtOutstanding;
        }
        if (excessWant > 0) {
            uint256[] memory liqAmounts = new uint256[](2);
            liqAmounts[0] = excessWant;
            liqAmounts[1] = 0;
            uint256 minAmount = (IRouter(HopStrategyLib.HOP_ROUTER)
                .calculateTokenAmount(address(this), liqAmounts, true) *
                slippage) / HopStrategyLib.MAX_BPS;

            IRouter(HopStrategyLib.HOP_ROUTER).addLiquidity(
                liqAmounts,
                minAmount,
                block.timestamp
            );
            uint256 lpBalance = IERC20(HopStrategyLib.LP).balanceOf(
                address(this)
            );
            IStakingRewards(HopStrategyLib.STAKING_REWARD).stake(lpBalance);
        }
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBal = want.balanceOf(address(this));
        if (_wantBal >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        _withdrawSome(_amountNeeded - _wantBal);
        _wantBal = want.balanceOf(address(this));

        if (_amountNeeded > _wantBal) {
            _liquidatedAmount = _wantBal;
            _loss = _amountNeeded - _wantBal;
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        _claimAndSellRewards();

        uint256 stakingAmount = balanceOfWant();
        IStakingRewards(HopStrategyLib.STAKING_REWARD).withdraw(stakingAmount);
        IRouter(HopStrategyLib.HOP_ROUTER).removeLiquidityOneToken(
            stakingAmount,
            0,
            0,
            block.timestamp
        );
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function balanceOfStaked() internal view returns (uint256 amount) {
        amount = IStakingRewards(HopStrategyLib.STAKING_REWARD).balanceOf(
            address(this)
        );
    }

    function rewardss() internal view returns (uint256 amount) {
        amount = IStakingRewards(HopStrategyLib.STAKING_REWARD).earned(
            address(this)
        );
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        if (HopStrategyLib.hopToWant(_swapHelperDTO, _quoteEventEmitter, rewardss(), address(want)) >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                balanceOfStaked(),
                _amountNeeded - HopStrategyLib.hopToWant(_swapHelperDTO, _quoteEventEmitter, rewardss(), address(want))
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimAndSellRewards() internal {
        IStakingRewards(HopStrategyLib.STAKING_REWARD).getReward();
        HopStrategyLib.sellHopForWant(
            _swapHelperDTO, 
            _swapEventEmitter, 
            IERC20(HopStrategyLib.HOP).balanceOf(address(this)),
            slippage
        );
    }

    function _exitPosition(uint256 _stakedAmount) internal {
        _claimAndSellRewards();
        uint256[] memory amountsToWithdraw = new uint256[](2);
        amountsToWithdraw[0] = _stakedAmount;
        amountsToWithdraw[1] = 0;

        uint256 amountLpToWithdraw = IRouter(HopStrategyLib.HOP_ROUTER)
            .calculateTokenAmount(address(this), amountsToWithdraw, false);

        if (amountLpToWithdraw > balanceOfWant()) {
            amountLpToWithdraw = balanceOfWant();
        }

        IStakingRewards(HopStrategyLib.STAKING_REWARD).withdraw(
            amountLpToWithdraw
        );
        uint256 minAmount = (_stakedAmount * slippage) / HopStrategyLib.MAX_BPS;

        IRouter(HopStrategyLib.HOP_ROUTER).removeLiquidityOneToken(
            amountLpToWithdraw,
            0,
            minAmount,
            block.timestamp
        );
    }

    function initializeQuoteBufferWithHopToWantValue()
        public
        onlyStrategistOrSelf
    {
        HopStrategyLib.hopToWant(_swapHelperDTO, _quoteEventEmitter, rewardss(), address(want));
    }

    function setSwapHelperDTO(SwapHelperDTO memory __swapHelperDTO) public onlyStrategistOrSelf {
        _swapHelperDTO = __swapHelperDTO;
    }

    function notifyCallback(
        address,
        address,
        uint256 amountOut,
        uint256
    ) external override onlySwapHelper {
        _swapHelperDTO.quoteBuffer = amountOut;
    }
}