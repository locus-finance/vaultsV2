// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../integrations/curve/IFactory.sol";
import "../integrations/curve/IPlainPool.sol";
import "../integrations/beefy/IBeefyVault.sol";

contract BeefyCurveStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    error WantTokenIsNotInPool(address pool);

    address public constant KAVA_CURVE_FACTORY =
        0x1764ee18e8B3ccA4787249Ceb249356192594585;
    address public constant KAVA_USDT =
        0x919C1c267BC06a7039e03fcc2eF738525769109c;
    address public constant KAVA_CURVE_AXLUSD_USDT_POOL_LP =
        0xAA3b055186f96dD29d0c2A17710d280Bc54290c7;
    address public constant KAVA_BEEFY_VAULT =
        0xd5BC6DEa24A93A542C0d3Aa7e4dFBD05d97AF0F8;

    uint256 public constant KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS = 2;
    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _strategyStargateChainId,
        uint16 _vaultStargateChainId,
        address _sgBridge,
        address _router
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultStargateChainId,
            _strategyStargateChainId,
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );
        IERC20(KAVA_USDT).approve(
            KAVA_CURVE_AXLUSD_USDT_POOL_LP,
            type(uint256).max
        );
        IERC20(KAVA_CURVE_AXLUSD_USDT_POOL_LP).approve(
            KAVA_BEEFY_VAULT,
            type(uint256).max
        );
    }

    function name() external pure override returns (string memory) {
        return "Kava - Beefy and Curve Strategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        IBeefyVault beefyVault = IBeefyVault(KAVA_BEEFY_VAULT);
        IPlainPool curvePool = IPlainPool(KAVA_CURVE_AXLUSD_USDT_POOL_LP);
        uint256 curveLpTokens = beefyVault.balanceOf(address(this)) *
            beefyVault.getPricePerFullShare();
        return
            balanceOfWant() +
            curvePool.calc_withdraw_one_coin(
                curveLpTokens,
                _getIndexOfWantTokenInCurvePool(address(curvePool))
            );
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        uint256 unstakedBalance = balanceOfWant();
        uint256 excessWant;
        if (unstakedBalance > _debtOutstanding) {
            excessWant = unstakedBalance - _debtOutstanding;
        }
        if (excessWant > 0) {
            _depositToBeefyVaultWantTokens(excessWant);
        }
    }

    function _depositToBeefyVaultWantTokens(
        uint256 amount
    ) internal returns (uint256 amountOfBeefyVaultTokensMinted) {
        IBeefyVault beefyVault = IBeefyVault(KAVA_BEEFY_VAULT);
        IPlainPool curvePool = IPlainPool(KAVA_CURVE_AXLUSD_USDT_POOL_LP);

        uint256[] memory amounts = new uint256[](
            KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS
        );

        uint256 wantTokenIndexInCurvePool = SafeCast.toUint256(
            _getIndexOfWantTokenInCurvePool(address(curvePool))
        );
        amounts[wantTokenIndexInCurvePool] = amount;
        uint256 curveSharesMinted = curvePool.add_liquidity(
            amounts,
            (amount * slippage) / 10000
        );
        uint256 oldBalanceOfBeefyVaultTokens = beefyVault.balanceOf(
            address(this)
        );
        beefyVault.deposit(curveSharesMinted);
        amountOfBeefyVaultTokensMinted =
            beefyVault.balanceOf(address(this)) -
            oldBalanceOfBeefyVaultTokens;
    }

    function _withdrawFromBeefyVaultAndTransformToWantTokens(
        uint256 wantTokensAmount
    ) internal returns (uint256 amountOfWantTokensWithdrawn) {
        IBeefyVault beefyVault = IBeefyVault(KAVA_BEEFY_VAULT);
        IPlainPool curvePool = IPlainPool(KAVA_CURVE_AXLUSD_USDT_POOL_LP);

        uint256[] memory amounts = new uint256[](
            KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS
        );
        uint256 wantTokenIndexInCurvePool = SafeCast.toUint256(
            _getIndexOfWantTokenInCurvePool(address(curvePool))
        );
        amounts[wantTokenIndexInCurvePool] = wantTokensAmount;

        uint256 amountToWithdrawFromBeefyVault = curvePool.calc_token_amount(
            amounts,
            true
        );

        beefyVault.withdraw(amountToWithdrawFromBeefyVault);

        amountOfWantTokensWithdrawn = curvePool.remove_liquidity_one_coin(
            wantTokensAmount,
            _getIndexOfWantTokenInCurvePool((address(curvePool))),
            (wantTokensAmount * slippage) / 10000
        );
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBalance = balanceOfWant();
        if (_wantBalance >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        _withdrawFromBeefyVaultAndTransformToWantTokens(
            _amountNeeded - _wantBalance
        );
        _wantBalance = balanceOfWant();

        if (_amountNeeded > _wantBalance) {
            _liquidatedAmount = _wantBalance;
            _loss = _amountNeeded - _wantBalance;
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        return
            _withdrawFromBeefyVaultAndTransformToWantTokens(
                IBeefyVault(KAVA_BEEFY_VAULT).balanceOf(address(this))
            );
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function _getIndexOfWantTokenInCurvePool(
        address pool
    ) internal view returns (int128) {
        IFactory curvePoolsFactory = IFactory(KAVA_CURVE_FACTORY);
        address[2] memory coins = curvePoolsFactory.get_coins(pool);
        if (coins[0] == address(want)) return 0;
        if (coins[1] == address(want)) return 1;
        revert WantTokenIsNotInPool(pool);
    }
}
