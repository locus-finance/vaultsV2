// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISwapChannel {
    function notifySwap(uint256 amount, address tokenIn) external returns (uint256 amountOut);

    function setCurrentSlippage(uint256 _newSlippage) external;

    function setUniswapV3Router(address _newRouter) external;

    function setTokenIn(address _newTokenIn) external;

    function setTokenOut(address _newTokenOut) external;

    function setPoolFee(uint24 _newPoolFee) external;
}
