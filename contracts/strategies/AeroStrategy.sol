// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { BaseStrategy } from "../BaseStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../integrations/velo/IVeloRouter.sol";
import "../integrations/velo/IVeloGauge.sol";

contract AeroStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    address internal constant AERO_ROUTER =
        0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address internal constant AERO_GAUGE =
        0xCF1D5Aa63083fda05c7f8871a9fDbfed7bA49060;
    address internal constant USDbC =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address internal constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address internal constant LP = 0x6EAB8c1B93f5799daDf2C687a30230a540DbD636;
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant POOL_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

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
        IERC20(USDbC).safeApprove(AERO_ROUTER, type(uint256).max);
        IERC20(LP).safeApprove(AERO_GAUGE, type(uint256).max);
        IERC20(LP).safeApprove(AERO_ROUTER, type(uint256).max);
        IERC20(AERO).safeApprove(AERO_ROUTER, type(uint256).max);
        IERC20(DAI).safeApprove(AERO_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "Aerodrome USDbC/DAI Strategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            LpToWant(balanceOfStaked()) +
            balanceOfWant() +
            AeroToWant(rewards());
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
            IVeloRouter.Route memory route;
            route.from = USDbC;
            route.to = DAI;
            route.stable = true;
            route.factory = POOL_FACTORY;
            (uint256 usdcAmount, uint256 daiAmount) = _calculateTokenAmounts(
                excessWant
            );
            _swapWantToDai(daiAmount);
            uint256 minAmountA = (usdcAmount * slippage) / 10000;
            uint256 minAmountB = ((daiAmount) * slippage) / 10000;
            IVeloRouter(AERO_ROUTER).addLiquidity(
                USDbC,
                DAI,
                true,
                usdcAmount,
                IERC20(DAI).balanceOf(address(this)),
                minAmountA,
                minAmountB,
                address(this),
                block.timestamp
            );
            uint256 lpBalance = IERC20(LP).balanceOf(address(this));
            IVeloGauge(AERO_GAUGE).deposit(lpBalance);
        }
    }

    function _calculateTokenAmounts(
        uint256 excessWant
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint256 desiredA, uint256 desiredB, ) = IVeloRouter(AERO_ROUTER)
            .quoteAddLiquidity(
                USDbC,
                DAI,
                true,
                POOL_FACTORY,
                excessWant / 2,
                (excessWant * 10 ** 12) / 2
            );
        desiredB = desiredB / 10 ** 12;
        uint256 sum = desiredB + desiredA;
        amountA = (excessWant * desiredA) / sum;
        amountB = excessWant - amountA;
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

    function _quoteMinAmountsRemove(
        uint256 amountLp
    ) internal view returns (uint256 minAmountA, uint256 minAmountB) {
        (minAmountA, minAmountB) = IVeloRouter(AERO_ROUTER)
            .quoteRemoveLiquidity(USDbC, DAI, true, POOL_FACTORY, amountLp);
        minAmountA = (minAmountA * slippage) / 10000;
        minAmountB = (minAmountB * slippage) / 10000;
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        _claimAndSellRewards();

        uint256 stakedAmount = balanceOfStaked();
        IVeloGauge(AERO_GAUGE).withdraw(stakedAmount);
        (uint256 minAmountA, uint256 minAmountB) = _quoteMinAmountsRemove(
            stakedAmount
        );
        IVeloRouter(AERO_ROUTER).removeLiquidity(
            USDbC,
            DAI,
            true,
            stakedAmount,
            minAmountA,
            minAmountB,
            address(this),
            block.timestamp
        );
        _swapDaiToWant(IERC20(DAI).balanceOf(address(this)));
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function balanceOfStaked() public view returns (uint256 amount) {
        amount = IVeloGauge(AERO_GAUGE).balanceOf(address(this));
    }

    function rewards() public view returns (uint256 amount) {
        amount = IVeloGauge(AERO_GAUGE).earned(address(this));
    }

    function LpToWant(
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        (uint256 amountOutA, uint256 AmountOutB) = IVeloRouter(AERO_ROUTER)
            .quoteRemoveLiquidity(USDbC, DAI, true, POOL_FACTORY, amountIn);
        amountOut = amountOutA + AmountOutB / 10 ** 12;
    }

    function AeroToWant(
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        IVeloRouter.Route[] memory route = new IVeloRouter.Route[](1);
        route[0].from = AERO;
        route[0].to = USDbC;
        route[0].stable = false;
        route[0].factory = POOL_FACTORY;
        amountOut = IVeloRouter(AERO_ROUTER).getAmountsOut(amountIn, route)[1];
    }

    function _swapWantToDai(uint256 amountToSell) internal {
        IVeloRouter.Route[] memory routes = new IVeloRouter.Route[](1);
        routes[0].from = USDbC;
        routes[0].to = DAI;
        routes[0].stable = true;
        routes[0].factory = POOL_FACTORY;
        uint256 amountOutMinimum = ((amountToSell * slippage) / 10000) *
            10 ** 12;
        (
            IVeloRouter(AERO_ROUTER).swapExactTokensForTokens(
                amountToSell,
                amountOutMinimum,
                routes,
                address(this),
                block.timestamp
            )
        );
    }

    function _swapDaiToWant(uint256 amountToSell) internal {
        IVeloRouter.Route[] memory routes = new IVeloRouter.Route[](1);
        routes[0].from = DAI;
        routes[0].to = USDbC;
        routes[0].stable = true;
        routes[0].factory = POOL_FACTORY;
        uint256 amountOutMinimum = (amountToSell * slippage) / 10000 / 10 ** 12;

        IVeloRouter(AERO_ROUTER).swapExactTokensForTokens(
            amountToSell,
            amountOutMinimum,
            routes,
            address(this),
            block.timestamp
        );
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        if (AeroToWant(rewards()) >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                LpToWant(balanceOfStaked()),
                _amountNeeded - AeroToWant(rewards())
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimAndSellRewards() internal {
        IVeloGauge(AERO_GAUGE).getReward(address(this));
        _sellAeroForWant(IERC20(AERO).balanceOf(address(this)));
    }

    function _exitPosition(uint256 _stakedAmount) internal {
        _claimAndSellRewards();
        (uint256 usdcAmount, ) = _calculateTokenAmounts(_stakedAmount);
        uint256 amountLpToWithdraw = (usdcAmount * IERC20(LP).totalSupply()) /
            IERC20(USDbC).balanceOf(LP);
        if (amountLpToWithdraw > balanceOfStaked()) {
            amountLpToWithdraw = balanceOfStaked();
        }
        IVeloGauge(AERO_GAUGE).withdraw(amountLpToWithdraw);
        (uint256 minAmountA, uint256 minAmountB) = _quoteMinAmountsRemove(
            amountLpToWithdraw
        );
        IVeloRouter(AERO_ROUTER).removeLiquidity(
            USDbC,
            DAI,
            true,
            amountLpToWithdraw,
            minAmountA,
            minAmountB,
            address(this),
            block.timestamp
        );
        _swapDaiToWant(IERC20(DAI).balanceOf(address(this)));
    }

    function _sellAeroForWant(uint256 amountToSell) internal {
        if (amountToSell == 0) {
            return;
        }
        IVeloRouter.Route[] memory route = new IVeloRouter.Route[](1);
        route[0].from = AERO;
        route[0].to = USDbC;
        route[0].stable = false;
        route[0].factory = POOL_FACTORY;
        uint256 amountOutMinimum = (AeroToWant(amountToSell) * slippage) /
            10000;
        IVeloRouter(AERO_ROUTER).swapExactTokensForTokens(
            amountToSell,
            amountOutMinimum,
            route,
            address(this),
            block.timestamp
        );
    }
}
