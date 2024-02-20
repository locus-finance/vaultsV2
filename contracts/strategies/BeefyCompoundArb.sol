// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../integrations/beefy/IBeefyVault.sol";

contract BeefyCompoundStrategy is Initializable, BaseStrategy, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    ///Want token is USDCe, but strategy required usdc.

    address public constant BEEFY_VAULT = 0xb9A27ba529634017b12e3cbbbFFb6dB7908a8C8B;
    uint256 public constant DEFAULT_SLIPPAGE = 9_800;
    uint32 public constant TWAP_RANGE_SECS = 1800;
    // TODO change addresses
    address public constant USDC = 0xb9A27ba529634017b12e3cbbbFFb6dB7908a8C8B;
    address public constant USDC_USDCE_UNI_POOL = 0xb9A27ba529634017b12e3cbbbFFb6dB7908a8C8B;
    uint256 internal constant USDC_USDCE_FEE = 100;
    address internal constant UNISWAP_V3_ROUTER = 0xb9A27ba529634017b12e3cbbbFFb6dB7908a8C8B;

    string private namePostfix;
    
    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
        IERC20 _want,
        address _vault,
        uint16 _vaultStargateChainId,
        uint16 _strategyStargateChainId,
        address _sgBridge,
        address _router,
        string calldata _namePostfix
    ) external initializer {
        __UUPSUpgradeable_init();
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _harvester,
            _want,
            _vault,
            _vaultStargateChainId,
            _strategyStargateChainId,
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );
        namePostfix = _namePostfix;
        IBeefyVault(BEEFY_VAULT).approve(BEEFY_VAULT, type(uint256).max);
        IERC20(USDC).approve(BEEFY_VAULT, type(uint256).max);
        IERC20(USDC).approve(UNISWAP_V3_ROUTER, type(uint256).max);
        IERC20(want).approve(UNISWAP_V3_ROUTER, type(uint256).max);
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner{}


    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Beefy - Compound ", namePostfix));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            balanceOfWant() +
             _UsdcToUsdce(IBeefyVault(BEEFY_VAULT).getPricePerFullShare() *
                IBeefyVault(BEEFY_VAULT).balanceOf(address(this))) /
            10 ** 18;
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
            uint256 out = _sellWantForUsdc(excessWant);
            IBeefyVault(BEEFY_VAULT).deposit(out);
        }
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBalance = balanceOfWant();
        if (_wantBalance >= _amountNeeded) {
            return (_amountNeeded, 0);
        }
        uint256 amountToWithdraw = (_UsdceToUsdc(_amountNeeded - _wantBalance) * 1e18) /
            IBeefyVault(BEEFY_VAULT).getPricePerFullShare();
        if (
            amountToWithdraw > IBeefyVault(BEEFY_VAULT).balanceOf(address(this))
        ) {
            amountToWithdraw = IBeefyVault(BEEFY_VAULT).balanceOf(
                address(this)
            );
        }
        IBeefyVault(BEEFY_VAULT).withdraw(amountToWithdraw);
        _sellUsdcForWant(IERC20(USDC).balanceOf(address(this)));

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
        _liquidatePosition(estimatedTotalAssets());
        return balanceOfWant();
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function smthToSmth(
        address pool,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(pool, TWAP_RANGE_SECS);
        return
            OracleLibrary.getQuoteAtTick(
                meanTick,
                uint128(amount),
                tokenFrom,
                tokenTo
            );
    }

    function _UsdceToUsdc(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        amountOut = smthToSmth(
            USDC_USDCE_UNI_POOL,
            address(want),
            USDC,
            amountIn
        );
    }

    function _UsdcToUsdce(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        amountOut = smthToSmth(
            USDC_USDCE_UNI_POOL,
            USDC,
            address(want),
            amountIn
        );
    }

    function _sellUsdcForWant(uint256 amountToSell) internal returns(uint256 out) {
        if (amountToSell == 0) {
            return 0 ;
        }
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            USDC,
            uint24(USDC_USDCE_FEE),
            address(want)
        );

        uint256 expected = _UsdcToUsdce(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum = (expected * slippage) / 10000;
        out = ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    }

    function _sellWantForUsdc(uint256 amountToSell) internal returns(uint256 out) {
        if (amountToSell == 0) {
            return 0;
        }
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            address(want),
            uint24(USDC_USDCE_FEE),
            USDC
        );

        uint256 expected = _UsdceToUsdc(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum = (expected * slippage) / 10000;
        out = ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    }
}
