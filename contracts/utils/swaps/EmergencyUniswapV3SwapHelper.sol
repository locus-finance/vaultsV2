// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../../interfaces/ISwapHelper.sol";

contract EmergencyUniswapV3SwapHelper is ISwapHelper {
    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override returns (uint256 amountOut) {
        // uint256 amountOut = requestQuoteOnUniswapV3(
        //     poolForEmergencyQuote,
        //     tokenFrom,
        //     tokenTo,
        //     amount
        // );
        // swapHelperDTO.quoteBuffer = amountOut;
        // emitEvent(tokenFrom, tokenTo, amount, lowLevelErrorData);


    }

    // function requestQuoteOnUniswapV3(
    //     address poolForEmergencyQuote,
    //     address tokenFrom,
    //     address tokenTo,
    //     uint256 amount
    // ) internal view returns (uint256) {
    //     (int24 meanTick, ) = OracleLibrary.consult(
    //         poolForEmergencyQuote,
    //         TWAP_RANGE_SECS
    //     );
    //     return
    //         OracleLibrary.getQuoteAtTick(
    //             meanTick,
    //             uint128(amount),
    //             tokenFrom,
    //             tokenTo
    //         );
    // }

    // function quoteHopToUsdc(uint256 amountToSell) internal view returns(uint256) {
    //     return requestQuoteOnUniswapV3(
    //         WETH_USDC_UNI_POOL,
    //         WETH,
    //         USDC,
    //         requestQuoteOnUniswapV3(
    //             HOP_WETH_UNI_POOL,
    //             HOP,
    //             WETH,
    //             amountToSell
    //         )
    //     );
    // }

    // function sellHopForWantOnUniswapV3(
    //     uint256 amountToSell,
    //     uint256 slippage
    // ) internal {
    //     ISwapRouter.ExactInputParams memory params;
    //     bytes memory swapPath = abi.encodePacked(
    //         HOP,
    //         uint24(HOP_WETH_POOL_FEE),
    //         WETH,
    //         uint24(USDC_WETH_POOL_FEE),
    //         USDC
    //     );

    //     uint256 usdcExpected = quoteHopToUsdc(amountToSell);
    //     params.path = swapPath;
    //     params.recipient = address(this);
    //     params.deadline = block.timestamp;
    //     params.amountIn = amountToSell;
    //     params.amountOutMinimum =
    //         (usdcExpected * slippage) /
    //         MAX_BPS;
    //     ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    // }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override {}
}
