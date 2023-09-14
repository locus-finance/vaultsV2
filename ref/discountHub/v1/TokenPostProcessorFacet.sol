// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../../interfaces/ISnacksPool.sol";
import "../../../interfaces/ISnacksMintRedeem.sol";
import "../interfaces/ITokenPostProcessor.sol";
import "../interfaces/IStaking.sol";
import "./base/DHBaseFacet.sol";

contract TokenPostProcessorFacet is ITokenPostProcessor, DHBaseFacet {
    using SafeERC20 for IERC20;

    function postProcessDeposit(
        address sender,
        address tokenIn,
        uint256 amountIn
    ) external override internalOnly returns (uint256 amountOut) {
        DHLib.Storage storage s = DHLib.get();
        address zoinks = s.primitives.zoinks;
        address snacks = s.primitives.snacks;
        if (zoinks != tokenIn && snacks != tokenIn) {
            revert BaseLib.InvalidAddress(tokenIn);
        }
        address snacksPoolAddress = s.primitives.snacksPool;
        amountOut = amountIn;
        if (zoinks == tokenIn) {
            amountOut = _transformZoinksToSnacks(
                sender,
                amountIn,
                zoinks,
                snacks,
                s
            );
            if (amountOut == 0) {
                emit Delayed(tokenIn, amountIn);
                return 0;
            }
        }
        IERC20 snacksInstance = IERC20(snacks);
        if (
            snacksInstance.allowance(address(this), snacksPoolAddress) <
            amountOut
        ) {
            snacksInstance.approve(snacksPoolAddress, type(uint256).max);
        }
        IStaking(address(this)).commonStake(amountOut);
        s.primitives.totalSnacksStaked += amountOut;
        s.mappings.snacksDepositOf[sender] += amountOut;
    }

    function postProcessWithdraw(
        address sender,
        address tokenIn,
        uint256 amountIn // if 0 then withdraw all and IN THIS CASE amountIn IS STRICTLY IN SNACKS WITH FEES ACCOUNTED
    ) external override internalOnly returns (uint256 amountOut) {
        DHLib.Storage storage s = DHLib.get();
        address zoinks = s.primitives.zoinks;
        address snacks = s.primitives.snacks;
        if (zoinks != tokenIn && snacks != tokenIn) {
            revert BaseLib.InvalidAddress(tokenIn);
        }
        address snacksPoolAddress = s.primitives.snacksPool;
        ISnacksPool snacksPool = ISnacksPool(snacksPoolAddress);
        amountIn = amountIn == 0 ? s.mappings.snacksDepositOf[sender] : amountIn;
        IStaking(address(this)).commonWithdraw(amountIn);
        if (
            block.timestamp <
            snacksPool.userLastDepositTime(address(this)) + 1 days
        ) {
            amountIn >>= 1; // fast div by 2
        }
        s.primitives.totalSnacksStaked -= amountIn;
        s.mappings.snacksDepositOf[sender] -= amountIn;
        amountOut = amountIn;
        if (zoinks == tokenIn) {
            amountOut = ISnacksMintRedeem(snacks).redeem(amountIn);
        }
    }

    function _transformZoinksToSnacks(
        address sender,
        uint256 amountIn,
        address zoinksAddress,
        address snacksAddress,
        DHLib.Storage storage s
    ) internal returns (uint256 snacksMinted) {
        ISnacksMintRedeem snacks = ISnacksMintRedeem(snacksAddress);
        IERC20 zoinks = IERC20(zoinksAddress);
        uint256 zoinksAllowance = zoinks.allowance(
            address(this),
            snacksAddress
        );
        if (zoinksAllowance < amountIn) {
            zoinks.approve(snacksAddress, type(uint256).max);
        }

        uint256 totalZoinks = s.mappings.unprocessedTokens[sender][
            zoinksAddress
        ] + amountIn;
        if (snacks.sufficientPayTokenAmountOnMint(totalZoinks)) {
            snacksMinted = snacks.mintWithPayTokenAmount(totalZoinks);
            s.mappings.unprocessedTokens[sender][zoinksAddress] = 0;
        } else {
            s.mappings.unprocessedTokens[sender][zoinksAddress] += amountIn;
        }
    }
}
