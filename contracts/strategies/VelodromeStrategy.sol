// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {BaseStrategy} from "../BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../integrations/velo/IVeloRouter.sol";
import "../integrations/velo/IVeloGauge.sol";

contract HopStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
    address internal constant VELO_GAUGE = 0xC263655114CdE848C73B899846FE7A2D219c10a8;
    address internal constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address internal constant USDPLUS = 0x73cb180bf0521828d8849bc8CF2B920918e23032;
    address internal constant LP = 0xd95E98fc33670dC033424E7Aa0578D742D00f9C7;
    address internal constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address internal constant DALA = 0x8aE125E8653821E851F12A49F7765db9a9ce7384;

    address internal constant WETH = 0x4200000000000000000000000000000000000006;

    address internal constant POOL_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    
    uint32 internal constant TWAP_RANGE_SECS = 1800;


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
        // IERC20(LP).safeApprove(STAKING_REWARD, type(uint256).max);
        // IERC20(LP).safeApprove(HOP_ROUTER, type(uint256).max);
        // IERC20(HOP).safeApprove(UNISWAP_V3_ROUTER, type(uint256).max);
        // want.safeApprove(HOP_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "Velo USDC/USD+ Strategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            LpToWant(balanceOfStaked()) +
            balanceOfWant() +
            VeloToWant(rewardss());
    }
    //to refactor due to amount of tokens changed
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
        route.from = USDC;
        route.to = USDPLUS;
        route.stable = false;
        route.factory = POOL_FACTORY;
        
            
            _swapWantToUsdplus(excessWant/2);
            uint256 minAmountA = excessWant/2 * slippage / 10000;
            uint256 minAmountB = IERC20(USDPLUS).balanceOf(address(this)) * slippage / 10000;
            IVeloRouter(VELO_ROUTER).addLiquidity(
                USDC,
                USDPLUS,
                true,
                excessWant / 2,
                IERC20(USDPLUS).balanceOf(address(this)),
                minAmountA,
                minAmountB,
                address(this),
                block.timestamp
            );
            uint256 lpBalance = IERC20(LP).balanceOf(address(this));
            IVeloGauge(VELO_GAUGE).deposit(lpBalance);
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

        uint256 stakedAmount = balanceOfStaked();
        IVeloGauge(VELO_GAUGE).withdraw(stakedAmount);
        IVeloRouter(VELO_ROUTER).removeLiquidity(
            USDC,
            USDPLUS,
            true,
            stakedAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
        _swapUsdplusToWant(IERC20(USDPLUS).balanceOf(address(this)));
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function balanceOfStaked() internal view returns (uint256 amount) {
        amount = IVeloGauge(VELO_GAUGE).balanceOf(address(this));
    }

    function rewardss() internal view returns (uint256 amount) {
        amount = IVeloGauge(VELO_GAUGE).earned(address(this));
    }

    function LpToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        (uint256 amountOutA, uint256 AmountOutB) = IVeloRouter(VELO_ROUTER).quoteRemoveLiquidity(
            USDC,
            USDPLUS,
            true,
            POOL_FACTORY,
            amountIn
        );
        amountOut = amountOutA + AmountOutB;
    }

    function VeloToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        IVeloRouter.Route[] memory route = new IVeloRouter.Route[](1);
        route[0].from = VELO;
        route[0].to = USDC;
        route[0].stable = false;
        route[0].factory = POOL_FACTORY;
        amountOut = IVeloRouter(VELO_ROUTER).getAmountsOut(amountIn, route)[1];
    }

    function _swapWantToUsdplus(uint256 amountToSell) internal{
        IVeloRouter.Route[] memory routes = new IVeloRouter.Route[](2);
        routes[0].from = USDC;
        routes[0].to = DALA;
        routes[0].stable = true;
        routes[0].factory = POOL_FACTORY;
        routes[1].from = DALA;
        routes[1].to = USDPLUS;
        routes[1].stable = true;
        routes[1].factory = POOL_FACTORY;
        //bigger slippage need to provide
        uint256 amountOutMinimum = (amountToSell * slippage) / 10000;
        (IVeloRouter(VELO_ROUTER).swapExactTokensForTokens(amountToSell, amountOutMinimum, routes, address(this), block.timestamp));
    }
    function _swapUsdplusToWant(uint256 amountToSell) internal{
        IVeloRouter.Route[] memory routes = new IVeloRouter.Route[](2);
        routes[0].from = USDPLUS;
        routes[0].to = DALA;
        routes[0].stable = true;
        routes[0].factory = POOL_FACTORY;
        routes[1].from = DALA;
        routes[1].to = USDC;
        routes[1].stable = true;
        routes[1].factory = POOL_FACTORY;
        //bigger slippage need to provide
        uint256 amountOutMinimum = (amountToSell * slippage) / 10000;
        (IVeloRouter(VELO_ROUTER).swapExactTokensForTokens(amountToSell, amountOutMinimum, routes, address(this), block.timestamp));
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        if (VeloToWant(rewardss()) >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                LpToWant(balanceOfStaked()),
                _amountNeeded - VeloToWant(rewardss())
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimAndSellRewards() internal {
        IVeloGauge(VELO_GAUGE).getReward(address(this));
        _sellVeloForWant(IERC20(VELO).balanceOf(address(this)));
    }

    function _exitPosition(uint256 _stakedAmount) internal {
        _claimAndSellRewards();

        uint256 amountLpToWithdraw = _stakedAmount * IERC20(LP).totalSupply() / IERC20(USDC).balanceOf(LP);

        if (amountLpToWithdraw > balanceOfWant()) {
            amountLpToWithdraw = balanceOfWant();
        }

        IVeloGauge(VELO_GAUGE).withdraw(amountLpToWithdraw);
        uint256 minAmount = (_stakedAmount * slippage) / 10000;

        IVeloRouter(VELO_ROUTER).removeLiquidity(
            USDC,
            USDPLUS,
            false,
            amountLpToWithdraw,
            minAmount,
            minAmount,
            address(this),
            block.timestamp
        );
    }

    function _sellVeloForWant(uint256 amountToSell) internal {
        if (amountToSell == 0) {
            return;
        }
        IVeloRouter.Route[] memory route = new IVeloRouter.Route[](1);
        route[0].from = VELO;
        route[0].to = USDC;
        route[0].stable = false;
        route[0].factory = POOL_FACTORY;
        
        uint256 amountOutMinimum = (VeloToWant(amountToSell) * slippage) / 10000;
        IVeloRouter(VELO_ROUTER).swapExactTokensForTokens(amountToSell, amountOutMinimum, route, address(this), block.timestamp);
    }
}
