// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IExchange} from "../integrations/usdr/IExchange.sol";
import {Utils} from "../utils/Utils.sol";
import {IV3SwapRouter} from "../integrations/uniswap/IV3SwapRouter.sol";
import {IPearlRouter, IPearlPair} from "../integrations/pearl/IPearlRouter.sol";
import {IPearlGaugeV2} from "../integrations/pearl/IPearlGaugeV2.sol";
import {BaseStrategy} from "../BaseStrategy.sol";

import "../utils/swaps/SwapHelperUser.sol";
import "./utils/PearlStrategyLib.sol";

contract PearlStrategy is Initializable, BaseStrategy, SwapHelperUser {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    address internal constant USDR = 0x40379a439D4F6795B6fc9aa5687dB461677A2dBa;
    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address internal constant PEARL =
        0x7238390d5f6F64e67c3211C343A410E2A3DEc142;

    address internal constant USDR_EXCHANGE =
        0x195F7B233947d51F4C3b756ad41a5Ddb34cEBCe0;

    address internal constant PEARL_USDR_LP =
        0xf68c20d6C50706f6C6bd8eE184382518C93B368c;
    address internal constant USDC_USDR_LP =
        0xD17cb0f162f133e339C0BbFc18c36c357E681D6b;
    address internal constant PEARL_GAUGE_V2 =
        0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876;

    uint256 internal constant MAX_BPS = 10000;

    uint8 public adjustedTo1InchSlippage;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20Metadata _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _router,
        address _swapHelper
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
            DEFAULT_SLIPPAGE
        );

        want.safeApprove(PearlStrategyLib.UNISWAP_V3_ROUTER, type(uint256).max);
        want.safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
        swapHelper = IOraclizedSwapHelper(_swapHelper);
        IERC20Metadata(USDR).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
        IERC20Metadata(USDC_USDR_LP).safeApprove(
            PEARL_GAUGE_V2,
            type(uint256).max
        );
        IERC20Metadata(USDC_USDR_LP).safeApprove(
            PearlStrategyLib.PEARL_ROUTER,
            type(uint256).max
        );
        IERC20Metadata(DAI).safeApprove(USDR_EXCHANGE, type(uint256).max);
        IERC20Metadata(PEARL).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);

        IERC20Metadata(USDR).safeApprove(_swapHelper, type(uint256).max);
        IERC20Metadata(DAI).safeApprove(_swapHelper, type(uint256).max);
        IERC20Metadata(PEARL).safeApprove(_swapHelper, type(uint256).max);

        adjustedTo1InchSlippage = uint8((slippage * 100) / MAX_BPS);
    }

    function name() external pure override returns (string memory) {
        return "PearlStrategy";
    }

    function balanceOfPearlRewards() public view returns (uint256) {
        return IPearlGaugeV2(PEARL_GAUGE_V2).earned(address(this));
    }

    function balanceOfLpStaked() public view returns (uint256) {
        return IPearlGaugeV2(PEARL_GAUGE_V2).balanceOf(address(this));
    }

    function pearlToWant(uint256 _pearlAmount) public view returns (uint256) {
        return
            PearlStrategyLib.pearlToWant(
                _pearlAmount,
                PEARL_USDR_LP,
                PEARL,
                USDR,
                wantDecimals
            );
    }

    function daiToWant(uint256 _daiAmount) public view returns (uint256) {
        return
            Utils.scaleDecimals(
                _daiAmount,
                IERC20Metadata(DAI).decimals(),
                wantDecimals
            );
    }

    function usdrToWant(uint256 _usdrAmount) public view returns (uint256) {
        return PearlStrategyLib.usdrToWant(_usdrAmount, USDR, wantDecimals);
    }

    function usdrLpToWant(uint256 _usdrLpAmount) public view returns (uint256) {
        (uint256 amountA, uint256 amountB) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
            .quoteRemoveLiquidity(address(want), USDR, true, _usdrLpAmount);
        return amountA + usdrToWant(amountB);
    }

    function wantToUsdrLp(uint256 _wantAmount) public view returns (uint256) {
        uint256 oneLp = usdrLpToWant(
            10 ** IERC20Metadata(USDC_USDR_LP).decimals()
        );
        uint256 scaledWantAmount = Utils.scaleDecimals(
            _wantAmount,
            wantDecimals,
            IERC20Metadata(USDC_USDR_LP).decimals()
        );
        uint256 scaledLp = Utils.scaleDecimals(
            oneLp,
            wantDecimals,
            IERC20Metadata(USDC_USDR_LP).decimals()
        );

        return
            (scaledWantAmount *
                (10 ** IERC20Metadata(USDC_USDR_LP).decimals())) / scaledLp;
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            want.balanceOf(address(this)) +
            pearlToWant(
                balanceOfPearlRewards() +
                    IERC20Metadata(PEARL).balanceOf(address(this))
            ) +
            usdrLpToWant(balanceOfLpStaked());
    }

    function _sellUsdr(uint256 _usdrAmount) internal {
        if (_usdrAmount == 0) {
            return;
        }
        swapHelper.requestSwapAndFulfillOnOracleExpense(
            USDR,
            address(want),
            _usdrAmount,
            adjustedTo1InchSlippage
        );
    }

    function _sellPearl(uint256 _pearlAmount) internal {
        if (_pearlAmount == 0) {
            return;
        }
        swapHelper.requestSwapAndFulfillOnOracleExpense(
            PEARL,
            address(want),
            _pearlAmount,
            adjustedTo1InchSlippage
        );
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }

        uint256 rewardsTotal = pearlToWant(balanceOfPearlRewards());
        if (rewardsTotal >= _amountNeeded) {
            IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
            _sellPearl(IERC20Metadata(PEARL).balanceOf(address(this)));
        } else {
            uint256 lpTokensToWithdraw = Math.min(
                wantToUsdrLp(_amountNeeded - rewardsTotal),
                balanceOfLpStaked()
            );
            _exitPosition(lpTokensToWithdraw);
        }
    }

    function _exitPosition(uint256 _stakedLpTokens) internal {
        IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
        _sellPearl(IERC20Metadata(PEARL).balanceOf(address(this)));

        if (_stakedLpTokens == 0) {
            return;
        }

        IPearlGaugeV2(PEARL_GAUGE_V2).withdraw(_stakedLpTokens);
        (uint256 amountA, uint256 amountB) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
            .quoteRemoveLiquidity(address(want), USDR, true, _stakedLpTokens);
        IPearlRouter(PearlStrategyLib.PEARL_ROUTER).removeLiquidity(
            address(want),
            USDR,
            true,
            _stakedLpTokens,
            _withSlippage(amountA),
            _withSlippage(amountB),
            address(this),
            block.timestamp
        );

        _sellUsdr(IERC20Metadata(USDR).balanceOf(address(this)));
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
        _exitPosition(balanceOfLpStaked());
        _amountFreed = want.balanceOf(address(this));
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
        _sellPearl(IERC20Metadata(PEARL).balanceOf(address(this)));

        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > _debtOutstanding) {
            uint256 excessWant = wantBal - _debtOutstanding;
            uint256 halfWant = excessWant / 2;

            swapHelper.requestSwapAndFulfillOnOracleExpense(
                address(want),
                DAI,
                halfWant,
                adjustedTo1InchSlippage
            );
        }

        uint256 daiBal = IERC20Metadata(DAI).balanceOf(address(this));
        if (daiBal > 0) {
            IExchange(USDR_EXCHANGE).swapFromUnderlying(daiBal, address(this));
        }

        uint256 usdrBal = IERC20Metadata(USDR).balanceOf(address(this));
        wantBal = want.balanceOf(address(this));
        if (usdrBal > 0 && wantBal > 0) {
            (uint256 amountA, uint256 amountB, ) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
                .quoteAddLiquidity(address(want), USDR, true, wantBal, usdrBal);
            IPearlRouter(PearlStrategyLib.PEARL_ROUTER).addLiquidity(
                address(want),
                USDR,
                true,
                amountA,
                amountB,
                1,
                1,
                address(this),
                block.timestamp
            );
        }

        uint256 usdrLpBal = IERC20Metadata(USDC_USDR_LP).balanceOf(
            address(this)
        );
        if (usdrLpBal > 0) {
            IPearlGaugeV2(PEARL_GAUGE_V2).deposit(usdrLpBal);
        }
    }

    function _prepareMigration(address _newStrategy) internal override {
        IPearlGaugeV2(PEARL_GAUGE_V2).withdraw(balanceOfLpStaked());

        IERC20Metadata(USDC_USDR_LP).safeTransfer(
            _newStrategy,
            IERC20Metadata(USDC_USDR_LP).balanceOf(address(this))
        );
        IERC20Metadata(USDR).safeTransfer(
            _newStrategy,
            IERC20Metadata(USDR).balanceOf(address(this))
        );
        IERC20Metadata(PEARL).safeTransfer(
            _newStrategy,
            IERC20Metadata(PEARL).balanceOf(address(this))
        );
    }

    function setSwapHelper(address __swapHelper) public onlyStrategistOrSelf {
        swapHelper = IOraclizedSwapHelper(__swapHelper);
    }
}
