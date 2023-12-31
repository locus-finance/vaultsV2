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

import "../integrations/beefy/IBeefyVault.sol";

contract BeefyCompoundStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    address public constant BEEFY_VAULT_BASE =
        0xD7803d3Bf95517D204CFc6211678cAb223aC4c48;

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

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
        IBeefyVault(BEEFY_VAULT_BASE).approve(BEEFY_VAULT_BASE, type(uint256).max);
        IERC20(want).approve(BEEFY_VAULT_BASE, type(uint256).max);
    }

    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Beefy - Compound ", namePostfix));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            balanceOfWant() +
            (IBeefyVault(BEEFY_VAULT_BASE).getPricePerFullShare() *
                IBeefyVault(BEEFY_VAULT_BASE).balanceOf(address(this))) /
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
            IBeefyVault(BEEFY_VAULT_BASE).deposit(excessWant);
        }
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBalance = balanceOfWant();
        if (_wantBalance >= _amountNeeded) {
            return (_amountNeeded, 0);
        }
        uint256 amountToWithdraw = ((_amountNeeded - _wantBalance) * 1e18) /
            IBeefyVault(BEEFY_VAULT_BASE).getPricePerFullShare();
        if (
            amountToWithdraw > IBeefyVault(BEEFY_VAULT_BASE).balanceOf(address(this))
        ) {
            amountToWithdraw = IBeefyVault(BEEFY_VAULT_BASE).balanceOf(
                address(this)
            );
        }
        IBeefyVault(BEEFY_VAULT_BASE).withdraw(amountToWithdraw);

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
}
