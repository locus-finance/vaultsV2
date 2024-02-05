// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IExchange} from "../../integrations/usdr/IExchange.sol";
import {Utils} from "../../utils/Utils.sol";
import {IV3SwapRouter} from "../../integrations/uniswap/IV3SwapRouter.sol";
import {IPearlRouter, IPearlPair} from "../../integrations/pearl/IPearlRouter.sol";
import {IPearlGaugeV2} from "../../integrations/pearl/IPearlGaugeV2.sol";
import {BaseStrategy} from "../../BaseStrategy.sol";

contract PearlStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    address internal constant USDR = 0x40379a439D4F6795B6fc9aa5687dB461677A2dBa;
    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address internal constant PEARL =
        0x7238390d5f6F64e67c3211C343A410E2A3DEc142;

    address internal constant DAI_USDC_V3_POOL =
        0x5645dCB64c059aa11212707fbf4E7F984440a8Cf;
    uint24 internal constant DAI_USDC_UNI_V3_FEE = 100;

    address internal constant UNISWAP_V3_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant USDR_EXCHANGE =
        0x195F7B233947d51F4C3b756ad41a5Ddb34cEBCe0;
    address internal constant PEARL_ROUTER =
        0xcC25C0FD84737F44a7d38649b69491BBf0c7f083;

    address internal constant PEARL_USDR_LP =
        0xf68c20d6C50706f6C6bd8eE184382518C93B368c;
    address internal constant USDC_USDR_LP =
        0xD17cb0f162f133e339C0BbFc18c36c357E681D6b;
    address internal constant PEARL_GAUGE_V2 =
        0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
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
            _harvester,
            _want,
            _vault,
            _vaultChainId,
            _currentChainId,
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );

        want.safeApprove(UNISWAP_V3_ROUTER, type(uint256).max);
        want.safeApprove(PEARL_ROUTER, type(uint256).max);

        IERC20(USDR).safeApprove(PEARL_ROUTER, type(uint256).max);
        IERC20(USDC_USDR_LP).safeApprove(PEARL_GAUGE_V2, type(uint256).max);
        IERC20(USDC_USDR_LP).safeApprove(PEARL_ROUTER, type(uint256).max);
        IERC20(DAI).safeApprove(USDR_EXCHANGE, type(uint256).max);
        IERC20(PEARL).safeApprove(PEARL_ROUTER, type(uint256).max);
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
        uint256 usdrAmount = IPearlPair(PEARL_USDR_LP).current(
            PEARL,
            _pearlAmount
        );
        return usdrToWant(usdrAmount);
    }

    function daiToWant(uint256 _daiAmount) public view returns (uint256) {
        return
            Utils.scaleDecimals(
                _daiAmount,
                ERC20(DAI).decimals(),
                wantDecimals
            );
    }

    function usdrToWant(uint256 _usdrAmount) public view returns (uint256) {
        return
            Utils.scaleDecimals(
                _usdrAmount,
                ERC20(USDR).decimals(),
                wantDecimals
            );
    }

    function usdrLpToWant(uint256 _usdrLpAmount) public view returns (uint256) {
        (uint256 amountA, uint256 amountB) = IPearlRouter(PEARL_ROUTER)
            .quoteRemoveLiquidity(address(want), USDR, true, _usdrLpAmount);
        return amountA + usdrToWant(amountB);
    }

    function wantToUsdrLp(uint256 _wantAmount) public view returns (uint256) {
        uint256 oneLp = usdrLpToWant(10 ** ERC20(USDC_USDR_LP).decimals());
        uint256 scaledWantAmount = Utils.scaleDecimals(
            _wantAmount,
            wantDecimals,
            ERC20(USDC_USDR_LP).decimals()
        );
        uint256 scaledLp = Utils.scaleDecimals(
            oneLp,
            wantDecimals,
            ERC20(USDC_USDR_LP).decimals()
        );

        return
            (scaledWantAmount * (10 ** ERC20(USDC_USDR_LP).decimals())) /
            scaledLp;
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            want.balanceOf(address(this)) +
            pearlToWant(
                balanceOfPearlRewards() + ERC20(PEARL).balanceOf(address(this))
            ) +
            usdrLpToWant(balanceOfLpStaked());
    }

    function _sellUsdr(uint256 _usdrAmount) internal {
        if (_usdrAmount == 0) {
            return;
        }

        uint256 wantAmountExpected = usdrToWant(_usdrAmount);
        IPearlRouter(PEARL_ROUTER).swapExactTokensForTokensSimple(
            _usdrAmount,
            _withSlippage(wantAmountExpected),
            USDR,
            address(want),
            true,
            address(this),
            block.timestamp
        );
    }

    function _sellPearl(uint256 _pearlAmount) internal {
        if (_pearlAmount == 0) {
            return;
        }

        IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
        routes[0] = IPearlRouter.Route({from: PEARL, to: USDR, stable: false});
        routes[1] = IPearlRouter.Route({
            from: USDR,
            to: address(want),
            stable: true
        });

        uint256 wantAmountExpected = pearlToWant(_pearlAmount);

        try
            IPearlRouter(PEARL_ROUTER).swapExactTokensForTokens(
                _pearlAmount,
                _withSlippage(wantAmountExpected),
                routes,
                address(this),
                block.timestamp
            )
        returns (uint256[] memory) {} catch {}
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }

        uint256 rewardsTotal = pearlToWant(balanceOfPearlRewards());
        if (rewardsTotal >= _amountNeeded) {
            IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
            _sellPearl(ERC20(PEARL).balanceOf(address(this)));
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
        _sellPearl(ERC20(PEARL).balanceOf(address(this)));

        if (_stakedLpTokens == 0) {
            return;
        }

        IPearlGaugeV2(PEARL_GAUGE_V2).withdraw(_stakedLpTokens);
        (uint256 amountA, uint256 amountB) = IPearlRouter(PEARL_ROUTER)
            .quoteRemoveLiquidity(address(want), USDR, true, _stakedLpTokens);
        IPearlRouter(PEARL_ROUTER).removeLiquidity(
            address(want),
            USDR,
            true,
            _stakedLpTokens,
            _withSlippage(amountA),
            _withSlippage(amountB),
            address(this),
            block.timestamp
        );

        _sellUsdr(ERC20(USDR).balanceOf(address(this)));
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
        _sellPearl(ERC20(PEARL).balanceOf(address(this)));

        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > _debtOutstanding) {
            uint256 excessWant = wantBal - _debtOutstanding;
            uint256 halfWant = excessWant / 2;
            uint256 scaledHalfWant = Utils.scaleDecimals(
                halfWant,
                wantDecimals,
                ERC20(DAI).decimals()
            );

            IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
                .ExactInputParams({
                    path: abi.encodePacked(
                        address(want),
                        DAI_USDC_UNI_V3_FEE,
                        DAI
                    ),
                    recipient: address(this),
                    amountIn: halfWant,
                    amountOutMinimum: _withSlippage(scaledHalfWant)
                });

            IV3SwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
        }

        uint256 daiBal = IERC20(DAI).balanceOf(address(this));
        if (daiBal > 0) {
            IExchange(USDR_EXCHANGE).swapFromUnderlying(daiBal, address(this));
        }

        uint256 usdrBal = IERC20(USDR).balanceOf(address(this));
        wantBal = want.balanceOf(address(this));
        if (usdrBal > 0 && wantBal > 0) {
            (uint256 amountA, uint256 amountB, ) = IPearlRouter(PEARL_ROUTER)
                .quoteAddLiquidity(address(want), USDR, true, wantBal, usdrBal);
            IPearlRouter(PEARL_ROUTER).addLiquidity(
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

        uint256 usdrLpBal = IERC20(USDC_USDR_LP).balanceOf(address(this));
        if (usdrLpBal > 0) {
            IPearlGaugeV2(PEARL_GAUGE_V2).deposit(usdrLpBal);
        }
    }

    function _prepareMigration(address _newStrategy) internal override {
        IPearlGaugeV2(PEARL_GAUGE_V2).withdraw(balanceOfLpStaked());

        IERC20(USDC_USDR_LP).safeTransfer(
            _newStrategy,
            IERC20(USDC_USDR_LP).balanceOf(address(this))
        );
        IERC20(USDR).safeTransfer(
            _newStrategy,
            IERC20(USDR).balanceOf(address(this))
        );
        IERC20(PEARL).safeTransfer(
            _newStrategy,
            IERC20(PEARL).balanceOf(address(this))
        );
    }
}
