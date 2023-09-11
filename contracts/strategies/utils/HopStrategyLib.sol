// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {SwapHelperDTO} from "../../utils/SwapHelperUser.sol";

import "../../integrations/hop/IRouter.sol";

/// @notice The contract is built to avoid max size per contract file constraint.
library HopStrategyLib 
{

    error InitializeQuoteBufferWithHopToWantValue();

    address internal constant HOP_ROUTER =
        0x10541b07d8Ad2647Dc6cD67abd4c03575dade261;
    address internal constant STAKING_REWARD =
        0xb0CabFE930642AD3E7DECdc741884d8C3F7EbC70;
    address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant LP = 0xB67c014FA700E69681a673876eb8BAFAA36BFf71;
    address internal constant HOP = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;

    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant HOP_WETH_UNI_POOL =
        0x44ca2BE2Bd6a7203CCDBb63EED8382274f737A15;
    address internal constant WETH_USDC_UNI_POOL =
        0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
    uint256 internal constant HOP_WETH_POOL_FEE = 3000;
    uint256 internal constant USDC_WETH_POOL_FEE = 500;
    address internal constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    uint32 internal constant TWAP_RANGE_SECS = 1800;

    address internal constant ETH_USDC_UNI_V3_POOL =
        0xC6962004f452bE9203591991D15f6b388e09E8D0;

    uint256 public constant MAX_BPS = 10000;

    function lpToWant(
        uint256 amountIn,
        address lpReceiver
    ) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        amountOut = IRouter(HOP_ROUTER)
            .calculateRemoveLiquidityOneToken(lpReceiver, amountIn, 0);
    }

    function hopToWant(
        SwapHelperDTO storage swapHelperDTO,
        function (address, address, uint256, bytes memory) internal quoteEventEmitter,
        uint256 amountIn, 
        address want
    ) internal returns (uint256 amountOut) {
        amountOut = requestQuote(
                swapHelperDTO,
                quoteEventEmitter,
                HOP_WETH_UNI_POOL,
                HOP,
                WETH,
                amountIn
            );
        amountOut = requestQuote(
            swapHelperDTO,
            quoteEventEmitter,
            WETH_USDC_UNI_POOL,
            WETH,
            want,
            amountOut // for gas economy reusing the result var
        );
        swapHelperDTO.isQuoteBufferContainsHopToWantValue = true;
    }

    function requestQuote(
        SwapHelperDTO storage swapHelperDTO,
        // if an errorData isn't empty - then an emergency quote operation happened
        function (address, address, uint256, bytes memory) internal emitEvent,
        address poolForEmergencyQuote,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal returns (uint256 tokensOut) {
        // why? to account if requestQuote(...) is utilized not only in hopToValue
        swapHelperDTO.isQuoteBufferContainsHopToWantValue = false;
        try
            swapHelperDTO.swapHelper.requestQuoteAndFulfillOnOracleExpense(
                tokenFrom,
                tokenTo,
                amount
            )
        {
            emitEvent(tokenFrom, tokenTo, amount, abi.encodePacked(uint256(0)));
        } 
        catch (bytes memory lowLevelErrorData) {
            uint256 amountOut = requestQuoteOnUniswapV3(
                poolForEmergencyQuote,
                tokenFrom,
                tokenTo,
                amount
            );
            swapHelperDTO.quoteBuffer = amountOut;
            emitEvent(tokenFrom, tokenTo, amount, lowLevelErrorData);
        }
        tokensOut = swapHelperDTO.quoteBuffer;
    }

    function quoteHopToUsdc(uint256 amountToSell) internal view returns(uint256) {
        return requestQuoteOnUniswapV3(
            WETH_USDC_UNI_POOL,
            WETH,
            USDC,
            requestQuoteOnUniswapV3(
                HOP_WETH_UNI_POOL,
                HOP,
                WETH,
                amountToSell
            )
        );
    }

    function requestQuoteOnUniswapV3(
        address poolForEmergencyQuote,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(
            poolForEmergencyQuote,
            TWAP_RANGE_SECS
        );
        return
            OracleLibrary.getQuoteAtTick(
                meanTick,
                uint128(amount),
                tokenFrom,
                tokenTo
            );
    }

    function sellHopForWantOnUniswapV3(
        uint256 amountToSell,
        uint256 slippage
    ) internal {
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            HOP,
            uint24(HOP_WETH_POOL_FEE),
            WETH,
            uint24(USDC_WETH_POOL_FEE),
            USDC
        );

        uint256 usdcExpected = quoteHopToUsdc(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum =
            (usdcExpected * slippage) /
            MAX_BPS;
        ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    }

    function sellHopForWant(
        SwapHelperDTO storage swapHelperDTO,
        // if an errorData isn't empty - then an emergency swap operation happened
        function (address, address, uint256, bytes memory) internal emitEvent,
        uint256 amountToSell,
        uint256 slippage
    ) internal {
        if (amountToSell == 0) {
            return;
        }
        // hop to usdc
        uint8 adjustedTo1InchSlippage = uint8(
            (slippage * 100) / HopStrategyLib.MAX_BPS
        );
        try
            swapHelperDTO.swapHelper.requestSwapAndFulfillOnOracleExpense(
                HopStrategyLib.HOP,
                HopStrategyLib.USDC,
                amountToSell,
                adjustedTo1InchSlippage
            )
        {
            emitEvent(HOP, USDC, amountToSell, abi.encodePacked(uint256(0)));
        } catch (bytes memory lowLevelErrorData) {
            sellHopForWantOnUniswapV3(amountToSell, slippage);
            emitEvent(HOP, USDC, amountToSell, lowLevelErrorData);
        }
    }
}
