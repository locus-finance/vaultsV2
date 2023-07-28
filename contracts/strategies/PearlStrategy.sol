// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

import "hardhat/console.sol";

contract PearlStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    uint256 public constant DEFAULT_SLIPPAGE = 9_700;

    address internal constant USDR = 0xb5DFABd7fF7F83BAB83995E72A52B97ABb7bcf63;
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
        0xda822340F5E8216C277DBF66627648Ff5D57b527;

    address internal constant PEARL_USDR_LP =
        0x74ee7376Ac31628a66b2Bb0eb2D14b549AB37275;
    address internal constant USDC_USDR_LP =
        0xf6A72Bd46F53Cd5103812ea1f4B5CF38099aB797;
    address internal constant PEARL_GAUGE_V2 =
        0xf4d40A328CB2320c94F009E936f840D2d8931721;

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
        (, , uint256 liquidity) = IPearlRouter(PEARL_ROUTER).quoteAddLiquidity(
            address(want),
            USDR,
            true,
            _wantAmount,
            type(uint256).max
        );
        return usdrLpToWant(liquidity);
    }

    function harvest() external override onlyStrategist {
        IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
        _sellPearl(ERC20(PEARL).balanceOf(address(this)));

        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > 0) {
            uint256 halfWant = wantBal / 2;
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

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            want.balanceOf(address(this)) +
            pearlToWant(balanceOfPearlRewards()) +
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
        IPearlRouter(PEARL_ROUTER).swapExactTokensForTokens(
            _pearlAmount,
            _withSlippage(wantAmountExpected),
            routes,
            address(this),
            block.timestamp
        );
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
            console.log(
                "want to lp: %s",
                wantToUsdrLp(_amountNeeded - rewardsTotal)
            );
            console.log("want to lp: %s", balanceOfLpStaked());
            console.log("price of lp: %s", usdrLpToWant(balanceOfLpStaked()));
            uint256 lpTokensToWithdraw = Math.min(
                wantToUsdrLp(_amountNeeded - rewardsTotal),
                balanceOfLpStaked()
            );
            _exitPosition(lpTokensToWithdraw);
        }
    }

    function _exitPosition(uint256 _stakedLpTokens) internal {
        console.log(
            "exiting: %s, %s",
            _stakedLpTokens,
            usdrLpToWant(_stakedLpTokens)
        );
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
}
