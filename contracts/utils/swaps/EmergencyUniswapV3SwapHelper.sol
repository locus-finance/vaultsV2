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

    ///// 

    // IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
    // routes[0] = IPearlRouter.Route({from: PEARL, to: USDR, stable: false});
    // routes[1] = IPearlRouter.Route({
    //     from: USDR,
    //     to: address(want),
    //     stable: true
    // });

    // uint256 wantAmountExpected = pearlToWant(_pearlAmount);

    // try
    //     IPearlRouter(PEARL_ROUTER).swapExactTokensForTokens(
    //         _pearlAmount,
    //         _withSlippage(wantAmountExpected),
    //         routes,
    //         address(this),
    //         block.timestamp
    //     )
    // returns (uint256[] memory) {} catch {} 

    // uint256 scaledHalfWant = Utils.scaleDecimals(
    //     halfWant,
    //     wantDecimals,
    //     ERC20(DAI).decimals()
    // );
    // IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
    //     .ExactInputParams({
    //         path: abi.encodePacked(
    //             address(want),
    //             DAI_USDC_UNI_V3_FEE,
    //             DAI
    //         ),
    //         recipient: address(this),
    //         amountIn: halfWant,
    //         amountOutMinimum: _withSlippage(scaledHalfWant)
    //     });
    // IV3SwapRouter(UNISWAP_V3_ROUTER).exactInput(params);

    // IPearlRouter(PEARL_ROUTER).swapExactTokensForTokensSimple(
    //     _usdrAmount,
    //     _withSlippage(wantAmountExpected),
    //     USDR,
    //     address(want),
    //     true,
    //     address(this),
    //     block.timestamp
    // );

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override {}
}
