// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "../integrations/hop/IStakingRewards.sol";
import "../integrations/hop/IRouter.sol";
import "../interfaces/ISwapHelper.sol";
import "./utils/HopStrategyLib.sol";
import "../utils/SwapHelperSubscriber.sol";

contract HopStrategy is
    Initializable,
    BaseStrategy,
    SwapHelperSubscriber
{
    using SafeERC20 for IERC20;

    ISwapHelper public swapHelper;
    uint256 internal _quoteBuffer;
    bool internal _isQuoteBufferContainsHopToWantValue;

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
        __AccessControl_init();
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

    function initializeQuoteBufferWithHopToWantValue()
        public
        onlyStrategistOrSelf
    {
        HopToWant(rewardss());
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        if (!_isQuoteBufferContainsHopToWantValue) {
            revert HopStrategyLib.InitializeQuoteBufferWithHopToWantValue();
        }
        return LpToWant(balanceOfStaked()) + balanceOfWant() + _quoteBuffer;
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

    function _emergencySmthToSmth(
        address poolForEmergencyQuote,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(
            poolForEmergencyQuote,
            HopStrategyLib.TWAP_RANGE_SECS
        );
        return
            OracleLibrary.getQuoteAtTick(
                meanTick,
                uint128(amount),
                tokenFrom,
                tokenTo
            );
    }

    function smthToSmth(
        address poolForEmergencyQuote,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal returns (uint256) {
        // why? to account if smthToSmth(...) is utilized not only in HopToValue
        _isQuoteBufferContainsHopToWantValue = false;

        try
            swapHelper.requestQuoteAndFulfillOnOracleExpense(
                tokenFrom,
                tokenTo,
                amount
            )
        {
            emit Quote(tokenFrom, tokenTo, amount);
        } catch (bytes memory lowLevelErrorData) {
            uint256 amountOut = _emergencySmthToSmth(
                poolForEmergencyQuote,
                tokenFrom,
                tokenTo,
                amount
            );
            _quoteBuffer = amountOut;
            emit EmergencyQuoteOnAlternativeDEX(lowLevelErrorData);
        }
        return _quoteBuffer;
    }

    function LpToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        amountOut = IRouter(HopStrategyLib.HOP_ROUTER)
            .calculateRemoveLiquidityOneToken(address(this), amountIn, 0);
    }

    function HopToWant(uint256 amountIn) internal returns (uint256 amountOut) {
        amountOut = smthToSmth(
            HopStrategyLib.WETH_USDC_UNI_POOL,
            HopStrategyLib.WETH,
            address(want),
            smthToSmth(
                HopStrategyLib.HOP_WETH_UNI_POOL,
                HopStrategyLib.HOP,
                HopStrategyLib.WETH,
                amountIn
            )
        );
        _isQuoteBufferContainsHopToWantValue = true;
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        if (HopToWant(rewardss()) >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                balanceOfStaked(),
                _amountNeeded - HopToWant(rewardss())
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimAndSellRewards() internal {
        IStakingRewards(HopStrategyLib.STAKING_REWARD).getReward();
        _sellHopForWant(IERC20(HopStrategyLib.HOP).balanceOf(address(this)));
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

    function _emergencySellHopForWant(uint256 amountToSell) internal {
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            HopStrategyLib.HOP,
            uint24(HopStrategyLib.HOP_WETH_POOL_FEE),
            HopStrategyLib.WETH,
            uint24(HopStrategyLib.USDC_WETH_POOL_FEE),
            HopStrategyLib.USDC
        );

        uint256 usdcExpected = HopToWant(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum =
            (usdcExpected * slippage) /
            HopStrategyLib.MAX_BPS;
        ISwapRouter(HopStrategyLib.UNISWAP_V3_ROUTER).exactInput(params);
    }

    function _sellHopForWant(uint256 amountToSell) internal {
        if (amountToSell == 0) {
            return;
        }
        // hop to usdc
        uint8 adjustedTo1InchSlippage = uint8(
            (slippage * 100) / HopStrategyLib.MAX_BPS
        );
        try
            swapHelper.requestSwapAndFulfillOnOracleExpense(
                HopStrategyLib.HOP,
                HopStrategyLib.USDC,
                amountToSell,
                adjustedTo1InchSlippage
            )
        {
            emit Swap(
                HopStrategyLib.HOP,
                HopStrategyLib.USDC,
                amountToSell
            );
        } catch (bytes memory lowLevelErrorData) {
            _emergencySellHopForWant(amountToSell);
            emit EmergencySwapOnAlternativeDEX(lowLevelErrorData);
        }
    }

    function setSwapHelper(address _swapHelper) public onlyStrategistOrSelf {
        swapHelper = ISwapHelper(_swapHelper);
    }

    function notifyCallback(
        address,
        address,
        uint256 amountOut,
        uint256
    ) external override onlyRole(QUOTE_OPERATION_PROVIDER) {
        _quoteBuffer = amountOut;
    }
}
