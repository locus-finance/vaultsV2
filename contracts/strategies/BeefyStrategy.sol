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

contract BeefyStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    error WrongChainId(uint16 chainId);
    error WantTokenIsNotInPool(address pool);

    address public constant KAVA_CURVE_FACTORY = address(0);
    address public constant KAVA_USDT = address(0);
    address public constant KAVA_CURVE_AXLUSD_USDT_POOL = address(0);
    address public constant KAVA_BEEFY_VAULT = address(0);

    address public constant BASE_CURVE_FACTORY = address(0);
    address public constant BASE_USDBC = address(0);
    address public constant BASE_CURVE_4POOL = address(0);
    address public constant BASE_BEEFY_VAULT = address(0);

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    uint16 public constant BASE_CHAIN_ID = 8453;
    uint16 public constant KAVA_CHAIN_ID = 2222;

    IERC20 public baseCurveStableSwap4PoolLp;
    IERC20 public kavaCurveStableSwapAxlusdUsdtPoolLp;

    uint256 private baseCurveStableSwap4PoolLpNCoins;
    uint256 private kavaCurveStableSwapAxlusdUsdtPoolNCoins;

    string private namePostfix;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _router,
        string calldata _namePostfix
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            uint16(block.chainid),
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );
        namePostfix = _namePostfix;

        uint256[2] memory nCoinsInfo;
        if (block.chainid == BASE_CHAIN_ID) {
            IERC20(BASE_USDBC).approve(BASE_CURVE_4POOL, type(uint256).max);
            baseCurveStableSwap4PoolLp = IERC20(
                IPlainPool(BASE_CURVE_4POOL).lp_token()
            );
            baseCurveStableSwap4PoolLp.approve(
                BASE_BEEFY_VAULT,
                type(uint256).max
            );
            nCoinsInfo = IFactory(KAVA_CURVE_FACTORY).get_n_coins(
                address(baseCurveStableSwap4PoolLp)
            );
            baseCurveStableSwap4PoolLpNCoins = nCoinsInfo[0];
        } else if (block.chainid == KAVA_CHAIN_ID) {
            IERC20(KAVA_USDT).approve(
                KAVA_CURVE_AXLUSD_USDT_POOL,
                type(uint256).max
            );
            kavaCurveStableSwapAxlusdUsdtPoolLp = IERC20(
                IPlainPool(KAVA_CURVE_AXLUSD_USDT_POOL).lp_token()
            );
            kavaCurveStableSwapAxlusdUsdtPoolLp.approve(
                KAVA_BEEFY_VAULT,
                type(uint256).max
            );
            nCoinsInfo = IFactory(KAVA_CURVE_FACTORY).get_n_coins(
                address(kavaCurveStableSwapAxlusdUsdtPoolLp)
            );
            kavaCurveStableSwapAxlusdUsdtPoolNCoins = nCoinsInfo[0];
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }

    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Beefy - Curve ", namePostfix));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        IBeefyVault beefyVault = _getBeefyVault();
        IPlainPool curvePool = _getCurvePlainPool();
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
        IBeefyVault beefyVault = _getBeefyVault();
        IPlainPool curvePool = _getCurvePlainPool();

        uint256[] memory amounts = _prepareAmountsArrayForCurveInteraction();

        uint256 wantTokenIndexInCurvePool = SafeCast.toUint256(
            _getIndexOfWantTokenInCurvePool(address(curvePool))
        );
        amounts[wantTokenIndexInCurvePool] = amount;
        uint256 curveSharesMinted = curvePool.add_liquidity(
            amounts,
            (amount * DEFAULT_SLIPPAGE) / 10000
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
        IBeefyVault beefyVault = _getBeefyVault();
        IPlainPool curvePool = _getCurvePlainPool();

        uint256[] memory amounts = _prepareAmountsArrayForCurveInteraction();
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
            (wantTokensAmount * DEFAULT_SLIPPAGE) / 10000
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
                _getBeefyVault().balanceOf(address(this))
            );
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function _getBeefyVault() internal view returns (IBeefyVault beefyVault) {
        if (block.chainid == BASE_CHAIN_ID) {
            beefyVault = IBeefyVault(BASE_BEEFY_VAULT);
        } else if (block.chainid == KAVA_CHAIN_ID) {
            beefyVault = IBeefyVault(KAVA_BEEFY_VAULT);
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }

    function _getCurvePlainPool() internal view returns (IPlainPool curvePool) {
        if (block.chainid == BASE_CHAIN_ID) {
            curvePool = IPlainPool(BASE_CURVE_4POOL);
        } else if (block.chainid == KAVA_CHAIN_ID) {
            curvePool = IPlainPool(KAVA_CURVE_AXLUSD_USDT_POOL);
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }

    function _getIndexOfWantTokenInCurvePool(
        address pool
    ) internal view returns (int128) {
        IFactory curvePoolsFactory;
        if (block.chainid == BASE_CHAIN_ID) {
            curvePoolsFactory = IFactory(BASE_CURVE_FACTORY);
        } else if (block.chainid == KAVA_CHAIN_ID) {
            curvePoolsFactory = IFactory(KAVA_CURVE_FACTORY);
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
        address[2] memory coins = curvePoolsFactory.get_coins(pool);
        if (coins[0] == address(want)) return 0;
        if (coins[1] == address(want)) return 1;
        revert WantTokenIsNotInPool(pool);
    }

    function _prepareAmountsArrayForCurveInteraction() internal view returns (uint256[] memory amounts) {
        if (block.chainid == BASE_CHAIN_ID) {
            amounts = new uint256[](baseCurveStableSwap4PoolLpNCoins);
        } else if (block.chainid == KAVA_CHAIN_ID) {
            amounts = new uint256[](kavaCurveStableSwapAxlusdUsdtPoolNCoins);
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }
}
