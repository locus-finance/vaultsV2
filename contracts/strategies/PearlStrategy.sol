// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.18;

// import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

// import {IExchange} from "../integrations/usdr/IExchange.sol";
// import {Utils} from "../utils/Utils.sol";
// import {IV3SwapRouter} from "../integrations/uniswap/IV3SwapRouter.sol";
// import {IPearlRouter, IPearlPair} from "../integrations/pearl/IPearlRouter.sol";
// import {IPearlGaugeV2} from "../integrations/pearl/IPearlGaugeV2.sol";
// import {BaseStrategy} from "../BaseStrategy.sol";

// import "../interfaces/ISwapHelper.sol";
// import "../utils/SwapHelperUser.sol";
// import "./utils/PearlStrategyLib.sol";

// contract PearlStrategy is
//     Initializable,
//     BaseStrategy,
//     SwapHelperUser
// {
//     using SafeERC20 for IERC20;
//     using FixedPointMathLib for uint256;

//     ISwapHelper public swapHelper;

//     function initialize(
//         address _lzEndpoint,
//         address _strategist,
//         IERC20 _want,
//         address _vault,
//         uint16 _vaultChainId,
//         uint16 _currentChainId,
//         address _sgBridge,
//         address _router
//     ) external initializer {
//         __AccessControl_init();
//         __BaseStrategy_init(
//             _lzEndpoint,
//             _strategist,
//             _want,
//             _vault,
//             _vaultChainId,
//             _currentChainId,
//             _sgBridge,
//             _router,
//             PearlStrategyLib.DEFAULT_SLIPPAGE
//         );

//         want.safeApprove(PearlStrategyLib.UNISWAP_V3_ROUTER, type(uint256).max);
//         want.safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);

//         IERC20(PearlStrategyLib.USDR).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
//         IERC20(PearlStrategyLib.USDC_USDR_LP).safeApprove(PearlStrategyLib.PEARL_GAUGE_V2, type(uint256).max);
//         IERC20(PearlStrategyLib.USDC_USDR_LP).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
//         IERC20(PearlStrategyLib.DAI).safeApprove(PearlStrategyLib.USDR_EXCHANGE, type(uint256).max);
//         IERC20(PearlStrategyLib.PEARL).safeApprove(PearlStrategyLib.PEARL_ROUTER, type(uint256).max);
//     }

//     function name() external pure override returns (string memory) {
//         return "PearlStrategy";
//     }

//     function balanceOfPearlRewards() public view returns (uint256) {
//         return IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).earned(address(this));
//     }

//     function balanceOfLpStaked() public view returns (uint256) {
//         return IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).balanceOf(address(this));
//     }

//     function pearlToWant(uint256 _pearlAmount) public view returns (uint256) {
//         uint256 usdrAmount = IPearlPair(PearlStrategyLib.PEARL_USDR_LP).current(
//             PearlStrategyLib.PEARL,
//             _pearlAmount
//         );
//         return usdrToWant(usdrAmount);
//     }

//     function daiToWant(uint256 _daiAmount) public view returns (uint256) {
//         return
//             Utils.scaleDecimals(
//                 _daiAmount,
//                 ERC20(PearlStrategyLib.DAI).decimals(),
//                 wantDecimals
//             );
//     }

//     /// @dev here
//     function usdrToWant(uint256 _usdrAmount) public view returns (uint256) {
//         // return
//         //     Utils.scaleDecimals(
//         //         _usdrAmount,
//         //         ERC20(PearlStrategyLib.USDR).decimals(),
//         //         wantDecimals
//         //     );
//     }

//     function usdrLpToWant(uint256 _usdrLpAmount) public view returns (uint256) {
//         (uint256 amountA, uint256 amountB) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
//             .quoteRemoveLiquidity(address(want), PearlStrategyLib.USDR, true, _usdrLpAmount);
//         return amountA + usdrToWant(amountB);
//     }

//     function wantToUsdrLp(uint256 _wantAmount) public view returns (uint256) {
//         uint256 oneLp = usdrLpToWant(10 ** ERC20(PearlStrategyLib.USDC_USDR_LP).decimals());
//         uint256 scaledWantAmount = Utils.scaleDecimals(
//             _wantAmount,
//             wantDecimals,
//             ERC20(PearlStrategyLib.USDC_USDR_LP).decimals()
//         );
//         uint256 scaledLp = Utils.scaleDecimals(
//             oneLp,
//             wantDecimals,
//             ERC20(PearlStrategyLib.USDC_USDR_LP).decimals()
//         );

//         return
//             (scaledWantAmount * (10 ** ERC20(PearlStrategyLib.USDC_USDR_LP).decimals())) /
//             scaledLp;
//     }

//     function estimatedTotalAssets() public view override returns (uint256) {
//         return
//             want.balanceOf(address(this)) +
//             pearlToWant(
//                 balanceOfPearlRewards() + ERC20(PearlStrategyLib.PEARL).balanceOf(address(this))
//             ) +
//             usdrLpToWant(balanceOfLpStaked());
//     }

//     function _sellUsdr(uint256 _usdrAmount) internal {
//         if (_usdrAmount == 0) {
//             return;
//         }
//         try
//             swapHelper.requestSwapAndFulfillOnOracleExpense(
//                 PearlStrategyLib.USDR,
//                 address(want),
//                 _usdrAmount,
//                 uint8((PearlStrategyLib.DEFAULT_SLIPPAGE * 100) / 10000) // converting into 1inch scaled slippage percent (10000 BPS -> 100%)
//             )
//         {
//             emit Swap(PearlStrategyLib.USDR, address(want), _usdrAmount);
//         } catch (bytes memory lowLevelErrorData) {
//             _emergencySellUsdr(_usdrAmount);
//             emit EmergencySwapOnAlternativeDEX(lowLevelErrorData);
//         }
//     }

//     function _emergencySellPearl(uint256 _pearlAmount) internal {
//         IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
//         routes[0] = IPearlRouter.Route({from: PearlStrategyLib.PEARL, to: PearlStrategyLib.USDR, stable: false});
//         routes[1] = IPearlRouter.Route({
//             from: PearlStrategyLib.USDR,
//             to: address(want),
//             stable: true
//         });

//         uint256 wantAmountExpected = pearlToWant(_pearlAmount);

//         try
//             IPearlRouter(PearlStrategyLib.PEARL_ROUTER).swapExactTokensForTokens(
//                 _pearlAmount,
//                 _withSlippage(wantAmountExpected),
//                 routes,
//                 address(this),
//                 block.timestamp
//             )
//         returns (uint256[] memory) {} catch {}
//     }

//     function _sellPearl(uint256 _pearlAmount) internal {
//         if (_pearlAmount == 0) {
//             return;
//         }
//         try
//             swapHelper.requestSwapAndFulfillOnOracleExpense(
//                 PearlStrategyLib.PEARL,
//                 address(want),
//                 _pearlAmount,
//                 uint8((PearlStrategyLib.DEFAULT_SLIPPAGE * 100) / 10000) // converting into 1inch scaled slippage percent (10000 BPS -> 100%)
//             )
//         {
//             emit Swap(PearlStrategyLib.PEARL, address(want), _pearlAmount);
//         } catch (bytes memory lowLevelErrorData) {
//             _emergencySellPearl(_pearlAmount);
//             emit EmergencySwapOnAlternativeDEX(lowLevelErrorData);
//         }
//     }

//     function _withdrawSome(uint256 _amountNeeded) internal {
//         if (_amountNeeded == 0) {
//             return;
//         }

//         uint256 rewardsTotal = pearlToWant(balanceOfPearlRewards());
//         if (rewardsTotal >= _amountNeeded) {
//             IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).getReward();
//             _sellPearl(ERC20(PearlStrategyLib.PEARL).balanceOf(address(this)));
//         } else {
//             uint256 lpTokensToWithdraw = Math.min(
//                 wantToUsdrLp(_amountNeeded - rewardsTotal),
//                 balanceOfLpStaked()
//             );
//             _exitPosition(lpTokensToWithdraw);
//         }
//     }

//     function _exitPosition(uint256 _stakedLpTokens) internal {
//         IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).getReward();
//         _sellPearl(ERC20(PearlStrategyLib.PEARL).balanceOf(address(this)));

//         if (_stakedLpTokens == 0) {
//             return;
//         }

//         IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).withdraw(_stakedLpTokens);
//         (uint256 amountA, uint256 amountB) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
//             .quoteRemoveLiquidity(address(want), PearlStrategyLib.USDR, true, _stakedLpTokens);
//         IPearlRouter(PearlStrategyLib.PEARL_ROUTER).removeLiquidity(
//             address(want),
//             PearlStrategyLib.USDR,
//             true,
//             _stakedLpTokens,
//             _withSlippage(amountA),
//             _withSlippage(amountB),
//             address(this),
//             block.timestamp
//         );

//         _sellUsdr(ERC20(PearlStrategyLib.USDR).balanceOf(address(this)));
//     }

//     function _liquidatePosition(
//         uint256 _amountNeeded
//     ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
//         uint256 _wantBal = want.balanceOf(address(this));
//         if (_wantBal >= _amountNeeded) {
//             return (_amountNeeded, 0);
//         }

//         _withdrawSome(_amountNeeded - _wantBal);
//         _wantBal = want.balanceOf(address(this));

//         if (_amountNeeded > _wantBal) {
//             _liquidatedAmount = _wantBal;
//             _loss = _amountNeeded - _wantBal;
//         } else {
//             _liquidatedAmount = _amountNeeded;
//         }
//     }

//     function _liquidateAllPositions()
//         internal
//         override
//         returns (uint256 _amountFreed)
//     {
//         _exitPosition(balanceOfLpStaked());
//         _amountFreed = want.balanceOf(address(this));
//     }

//     function _adjustPosition(uint256 _debtOutstanding) internal override {
//         IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).getReward();
//         _sellPearl(ERC20(PearlStrategyLib.PEARL).balanceOf(address(this)));

//         uint256 wantBal = want.balanceOf(address(this));

//         if (wantBal > _debtOutstanding) {
//             uint256 excessWant = wantBal - _debtOutstanding;
//             uint256 halfWant = excessWant / 2;
//             uint256 scaledHalfWant = Utils.scaleDecimals(
//                 halfWant,
//                 wantDecimals,
//                 ERC20(PearlStrategyLib.DAI).decimals()
//             );

//             IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
//                 .ExactInputParams({
//                     path: abi.encodePacked(
//                         address(want),
//                         PearlStrategyLib.DAI_USDC_UNI_V3_FEE,
//                         PearlStrategyLib.DAI
//                     ),
//                     recipient: address(this),
//                     amountIn: halfWant,
//                     amountOutMinimum: _withSlippage(scaledHalfWant)
//                 });

//             IV3SwapRouter(PearlStrategyLib.UNISWAP_V3_ROUTER).exactInput(params);
//         }

//         uint256 daiBal = IERC20(PearlStrategyLib.DAI).balanceOf(address(this));
//         if (daiBal > 0) {
//             IExchange(PearlStrategyLib.USDR_EXCHANGE).swapFromUnderlying(daiBal, address(this));
//         }

//         uint256 usdrBal = IERC20(PearlStrategyLib.USDR).balanceOf(address(this));
//         wantBal = want.balanceOf(address(this));
//         if (usdrBal > 0 && wantBal > 0) {
//             (uint256 amountA, uint256 amountB, ) = IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
//                 .quoteAddLiquidity(address(want), PearlStrategyLib.USDR, true, wantBal, usdrBal);
//             IPearlRouter(PearlStrategyLib.PEARL_ROUTER).addLiquidity(
//                 address(want),
//                 PearlStrategyLib.USDR,
//                 true,
//                 amountA,
//                 amountB,
//                 1,
//                 1,
//                 address(this),
//                 block.timestamp
//             );
//         }

//         uint256 usdrLpBal = IERC20(PearlStrategyLib.USDC_USDR_LP).balanceOf(address(this));
//         if (usdrLpBal > 0) {
//             IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).deposit(usdrLpBal);
//         }
//     }

//     function _prepareMigration(address _newStrategy) internal override {
//         IPearlGaugeV2(PearlStrategyLib.PEARL_GAUGE_V2).withdraw(balanceOfLpStaked());

//         IERC20(PearlStrategyLib.USDC_USDR_LP).safeTransfer(
//             _newStrategy,
//             IERC20(PearlStrategyLib.USDC_USDR_LP).balanceOf(address(this))
//         );
//         IERC20(PearlStrategyLib.USDR).safeTransfer(
//             _newStrategy,
//             IERC20(PearlStrategyLib.USDR).balanceOf(address(this))
//         );
//         IERC20(PearlStrategyLib.PEARL).safeTransfer(
//             _newStrategy,
//             IERC20(PearlStrategyLib.PEARL).balanceOf(address(this))
//         );
//     }

//     function setSwapHelper(address _swapHelper) public onlyStrategistOrSelf {
//         swapHelper = ISwapHelper(_swapHelper);
//     }
// }
