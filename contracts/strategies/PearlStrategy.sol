// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IExchange} from "../integrations/usdr/IExchange.sol";
import {Utils} from "../utils/Utils.sol";
import {IV3SwapRouter} from "../integrations/uniswap/IV3SwapRouter.sol";
import {IPearlRouter} from "../integrations/pearl/IPearlRouter.sol";
import {IPearlGaugeV2} from "../integrations/pearl/IPearlGaugeV2.sol";
import {BaseStrategy} from "../BaseStrategy.sol";

import "../interfaces/ISwapHelper.sol";
import "../utils/SwapHelperUser.sol";
import "./utils/PearlStrategyLib.sol";

contract PearlStrategy is
    Initializable,
    BaseStrategy,
    SwapHelperUser
{
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    function initialize(
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
            PearlStrategyLib.DEFAULT_SLIPPAGE
        );

        want.safeApprove(PearlStrategyLib.UNISWAP_V3_ROUTER, type(uint256).max);
        want.safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);

        IERC20(PearlStrategyLib.USDR).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
        IERC20(PearlStrategyLib.USDC_USDR_LP).safeApprove(PearlStrategyLib.PEARL_GAUGE_V2, type(uint256).max);
        IERC20(PearlStrategyLib.USDC_USDR_LP).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
        IERC20(PearlStrategyLib.DAI).safeApprove(PearlStrategyLib.USDR_EXCHANGE, type(uint256).max);
        IERC20(PearlStrategyLib.PEARL).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "PearlStrategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            want.balanceOf(address(this)) +
            PearlStrategyLib.pearlToWant(
                PearlStrategyLib.balanceOfPearlRewards() + IERC20Metadata(PearlStrategyLib.PEARL).balanceOf(address(this)),
                wantDecimals
            ) + 
            PearlStrategyLib.usdrLpToWant(
                PearlStrategyLib.balanceOfLpStaked(),
                address(want),
                wantDecimals
            );
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBal = want.balanceOf(address(this));
        if (_wantBal >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        PearlStrategyLib.withdrawSome(
            _amountNeeded - _wantBal,
            address(want),
            wantDecimals,
            _swapHelperDTO,
            _swapEventEmitter,
            __innerWithSlippage
        );
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
        PearlStrategyLib.exitPosition(
            PearlStrategyLib.balanceOfLpStaked(),
            address(want),
            wantDecimals,
            _swapHelperDTO,
            _swapEventEmitter,
            __innerWithSlippage
        );
        _amountFreed = want.balanceOf(address(this));
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).getReward();
        PearlStrategyLib.sellPearl(
            IERC20Metadata(PearlStrategyLib.PEARL).balanceOf(address(this)),
            address(want),
            wantDecimals,
            _swapHelperDTO,
            _swapEventEmitter,
            __innerWithSlippage
        );

        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > _debtOutstanding) {
            uint256 excessWant = wantBal - _debtOutstanding;
            uint256 halfWant = excessWant / 2;
            uint256 scaledHalfWant = Utils.scaleDecimals(
                halfWant,
                wantDecimals,
                IERC20Metadata(PearlStrategyLib.DAI).decimals()
            );

            IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
                .ExactInputParams({
                    path: abi.encodePacked(
                        address(want),
                        PearlStrategyLib.DAI_USDC_UNI_V3_FEE,
                        PearlStrategyLib.DAI
                    ),
                    recipient: address(this),
                    amountIn: halfWant,
                    amountOutMinimum: _withSlippage(scaledHalfWant)
                });

            IV3SwapRouter(PearlStrategyLib.UNISWAP_V3_ROUTER).exactInput(params);
        }

        uint256 daiBal = IERC20(PearlStrategyLib.DAI).balanceOf(address(this));
        if (daiBal > 0) {
            IExchange(PearlStrategyLib.USDR_EXCHANGE).swapFromUnderlying(daiBal, address(this));
        }

        uint256 usdrBal = IERC20(PearlStrategyLib.USDR).balanceOf(address(this));
        wantBal = want.balanceOf(address(this));
        if (usdrBal > 0 && wantBal > 0) {
            (uint256 amountA, uint256 amountB, ) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
                .quoteAddLiquidity(address(want), PearlStrategyLib.USDR, true, wantBal, usdrBal);
            IPearlRouter(PearlStrategyLib.PEARL_ROUTER).addLiquidity(
                address(want),
                PearlStrategyLib.USDR,
                true,
                amountA,
                amountB,
                1,
                1,
                address(this),
                block.timestamp
            );
        }

        uint256 usdrLpBal = IERC20(PearlStrategyLib.USDC_USDR_LP).balanceOf(address(this));
        if (usdrLpBal > 0) {
            IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).deposit(usdrLpBal);
        }
    }

    function _prepareMigration(address _newStrategy) internal override {
        IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).withdraw(
            PearlStrategyLib.balanceOfLpStaked()
        );

        IERC20(PearlStrategyLib.USDC_USDR_LP).safeTransfer(
            _newStrategy,
            IERC20(PearlStrategyLib.USDC_USDR_LP).balanceOf(address(this))
        );
        IERC20(PearlStrategyLib.USDR).safeTransfer(
            _newStrategy,
            IERC20(PearlStrategyLib.USDR).balanceOf(address(this))
        );
        IERC20(PearlStrategyLib.PEARL).safeTransfer(
            _newStrategy,
            IERC20(PearlStrategyLib.PEARL).balanceOf(address(this))
        );
    }

    function setSwapHelperDTO(SwapHelperDTO memory __swapHelperDTO) external onlyStrategistOrSelf {
        _swapHelperDTO = __swapHelperDTO;
    }

    /// @dev There is no syntax in Solidity that allows selection of overloaded functions 
    /// to be passed as Function Type parameters. So this is workaround.
    function __innerWithSlippage(uint256 amount) internal view returns(uint256) {
        return _withSlippage(amount);
    }
}
