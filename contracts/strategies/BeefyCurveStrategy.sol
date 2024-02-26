// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPlainPool} from "../integrations/curve/IPlainPool.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../integrations/beefy/IBeefyVault.sol";

contract BeefyCurveStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    address public constant BEEFY_VAULT =
        0xEc7c0205a6f426c2Cb1667d783B5B4fD2f875434;
    address public constant CURVE_POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    uint256 public constant DEFAULT_SLIPPAGE = 9_800;
    string private namePostfix;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
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
        IERC20(want).approve(CURVE_POOL, type(uint256).max);
        IERC20(CURVE_POOL).approve(BEEFY_VAULT, type(uint256).max);
        IERC20(CURVE_POOL).approve(CURVE_POOL, type(uint256).max);
    }

    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Beefy - Compound ", namePostfix));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            balanceOfWant() +
            _LpToWant((IBeefyVault(BEEFY_VAULT).getPricePerFullShare() *
                IBeefyVault(BEEFY_VAULT).balanceOf(address(this)) /
            10 ** 18));
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
            uint256[2] memory amountsIn = [excessWant, 0];
            uint256 minMintAmount = _calcMinMintAmount(amountsIn);
            IPlainPool(CURVE_POOL).add_liquidity(amountsIn,minMintAmount);
            IBeefyVault(BEEFY_VAULT).deposit(IERC20(CURVE_POOL).balanceOf(address(this)));
        }
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBalance = balanceOfWant();
        if (_wantBalance >= _amountNeeded) {
            return (_amountNeeded, 0);
        }
        uint256[2] memory amountsIn = [_amountNeeded - _wantBalance, 0];
        uint256 amountToWithdraw = (_wantToLp(amountsIn) * 1e18) /
            IBeefyVault(BEEFY_VAULT).getPricePerFullShare();
        if (
            amountToWithdraw > IBeefyVault(BEEFY_VAULT).balanceOf(address(this))
        ) {
            amountToWithdraw = IBeefyVault(BEEFY_VAULT).balanceOf(
                address(this)
            );
        }
        IBeefyVault(BEEFY_VAULT).withdraw(amountToWithdraw);
        uint256 currentLpBalance = IERC20(CURVE_POOL).balanceOf(address(this));
        uint256 minWithdrawAmount = _calcMinWithdrawAmount(currentLpBalance);
        IPlainPool(CURVE_POOL).remove_liquidity_one_coin(currentLpBalance,0,minWithdrawAmount);
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

    function _calcMinMintAmount(uint256[2] memory amount) internal view returns(uint256 out){
        out = IPlainPool(CURVE_POOL).calc_token_amount(amount, true) * slippage / MAX_BPS;
    }
    function _calcMinWithdrawAmount(uint256 amount) internal view returns(uint256 out){
        out = IPlainPool(CURVE_POOL).calc_withdraw_one_coin(amount, 0) * slippage / MAX_BPS;
    }

    function _LpToWant(uint256 amount) internal view returns(uint256 out){
        out = IPlainPool(CURVE_POOL).calc_withdraw_one_coin(amount, 0);
    }
    function _wantToLp(uint256[2] memory amount) internal view returns(uint256 out){
        out = IPlainPool(CURVE_POOL).calc_token_amount(amount, true);
    }
}
