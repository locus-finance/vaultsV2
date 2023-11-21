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

import "../integrations/curve/IPlainPool2Or4Coins.sol";
import "../integrations/beefy/IBeefyVault.sol";

contract BeefyStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    error WrongChainId(uint16 chainId);

    address public constant KAVA_USDT =
        0x919C1c267BC06a7039e03fcc2eF738525769109c;
    address public constant KAVA_CURVE_AXLUSD_USDT_POOL_LP =
        0xAA3b055186f96dD29d0c2A17710d280Bc54290c7;
    address public constant KAVA_BEEFY_VAULT =
        0xd5BC6DEa24A93A542C0d3Aa7e4dFBD05d97AF0F8;

    address public constant BASE_USDBC =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant BASE_CURVE_4POOL_LP =
        0xf6C5F01C7F3148891ad0e19DF78743D31E390D1f;
    address public constant BASE_BEEFY_VAULT =
        0xC3718d05478Edab1C40F84E8a7A65ca49D039A9f;

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant KAVA_CHAIN_ID = 2222;
    int128 public constant BASE_WANT_TOKEN_INDEX_IN_CURVE_POOL = 1;
    int128 public constant KAVA_WANT_TOKEN_INDEX_IN_CURVE_POOL = 0;

    uint256 public constant BASE_CURVE_STABLESWAP_FOR_POOL_LP_N_COINS = 4;
    uint256 public constant KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS = 2;

    string private namePostfix;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _strategyStargateChainId,
        uint16 _vaultStargateChainId,
        address _sgBridge,
        address _router,
        string calldata _namePostfix
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
        namePostfix = _namePostfix;

        if (block.chainid == BASE_CHAIN_ID) {
            IERC20(BASE_USDBC).approve(BASE_CURVE_4POOL_LP, type(uint256).max);
            IERC20(BASE_CURVE_4POOL_LP).approve(
                BASE_BEEFY_VAULT,
                type(uint256).max
            );
        } else if (block.chainid == KAVA_CHAIN_ID) {
            IERC20(KAVA_USDT).approve(
                KAVA_CURVE_AXLUSD_USDT_POOL_LP,
                type(uint256).max
            );
            IERC20(KAVA_CURVE_AXLUSD_USDT_POOL_LP).approve(
                KAVA_BEEFY_VAULT,
                type(uint256).max
            );
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }

    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Beefy - Curve ", namePostfix));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        IBeefyVault beefyVault = _getBeefyVault();
        IPlainPool2Or4Coins curvePool = _getCurvePlainPool();
        uint256 curveLpTokens = beefyVault.balanceOf(address(this)) *
            beefyVault.getPricePerFullShare();
        uint256 wantTokensInCurvePool;
        if (curveLpTokens > 0) {
            wantTokensInCurvePool = curvePool.calc_withdraw_one_coin(
                curveLpTokens,
                _getIndexOfWantTokenInCurvePool()
            );
        }
        return balanceOfWant() + wantTokensInCurvePool;
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
        IPlainPool2Or4Coins curvePool = _getCurvePlainPool();

        uint256[KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS] memory kavaAmounts;
        uint256[BASE_CURVE_STABLESWAP_FOR_POOL_LP_N_COINS] memory baseAmounts;

        uint256 wantTokenIndexInCurvePool = SafeCast.toUint256(
            _getIndexOfWantTokenInCurvePool()
        );

        uint256 curveSharesMinted;

        if (block.chainid == BASE_CHAIN_ID) {
            baseAmounts[wantTokenIndexInCurvePool] = amount;
            uint256 amountOfCurveLpsToBeAcquired = curvePool.calc_token_amount(
                baseAmounts,
                true
            );
            curveSharesMinted = curvePool.add_liquidity(
                baseAmounts,
                (amountOfCurveLpsToBeAcquired * DEFAULT_SLIPPAGE) / 10000,
                address(this)
            );
        } else if (block.chainid == KAVA_CHAIN_ID) {
            kavaAmounts[wantTokenIndexInCurvePool] = amount;
            uint256 amountOfCurveLpsToBeAcquired = curvePool.calc_token_amount(
                kavaAmounts,
                true
            );
            curveSharesMinted = curvePool.add_liquidity(
                kavaAmounts,
                (amountOfCurveLpsToBeAcquired * DEFAULT_SLIPPAGE) / 10000,
                address(this)
            );
        } else {
            revert WrongChainId(uint16(block.chainid));
        }

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
        IPlainPool2Or4Coins curvePool = _getCurvePlainPool();

        uint256[KAVA_CURVE_STABLESWAP_AXLUSD_USDT_POOL_N_COINS] memory kavaAmounts;
        uint256[BASE_CURVE_STABLESWAP_FOR_POOL_LP_N_COINS] memory baseAmounts;

        uint256 wantTokenIndexInCurvePool = SafeCast.toUint256(
            _getIndexOfWantTokenInCurvePool()
        );

        uint256 amountToWithdrawFromBeefyVault;

        if (block.chainid == BASE_CHAIN_ID) {
            baseAmounts[wantTokenIndexInCurvePool] = wantTokensAmount;
            amountToWithdrawFromBeefyVault = curvePool.calc_token_amount(
                baseAmounts,
                true
            );
        } else if (block.chainid == KAVA_CHAIN_ID) {
            kavaAmounts[wantTokenIndexInCurvePool] = wantTokensAmount;
            amountToWithdrawFromBeefyVault = curvePool.calc_token_amount(
                kavaAmounts,
                true
            );
        } else {
            revert WrongChainId(uint16(block.chainid));
        }

        beefyVault.withdraw(amountToWithdrawFromBeefyVault);

        amountOfWantTokensWithdrawn = curvePool.remove_liquidity_one_coin(
            wantTokensAmount,
            _getIndexOfWantTokenInCurvePool(),
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

    function _getCurvePlainPool() internal view returns (IPlainPool2Or4Coins curvePool) {
        if (block.chainid == BASE_CHAIN_ID) {
            curvePool = IPlainPool2Or4Coins(BASE_CURVE_4POOL_LP);
        } else if (block.chainid == KAVA_CHAIN_ID) {
            curvePool = IPlainPool2Or4Coins(KAVA_CURVE_AXLUSD_USDT_POOL_LP);
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }

    function _getIndexOfWantTokenInCurvePool() 
        internal 
        view 
        returns (int128)
    {
        if (block.chainid == BASE_CHAIN_ID) {
            return BASE_WANT_TOKEN_INDEX_IN_CURVE_POOL; 
        } else if (block.chainid == KAVA_CHAIN_ID) {
            return KAVA_WANT_TOKEN_INDEX_IN_CURVE_POOL;
        } else {
            revert WrongChainId(uint16(block.chainid));
        }
    }
}
