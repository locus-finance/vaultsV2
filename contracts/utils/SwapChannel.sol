// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../interfaces/ISwapChannel.sol";

contract SwapChannel is ISwapChannel, AccessControl {
    error InvalidTokenIn(address tokenIn, address expected);
    error InvalidSlippage(uint256 value);
    error NotEnough(address token, uint256 value, uint256 delta);

    uint256 public constant MAX_BPS = 10000;
    bytes32 public constant CHANNEL_OPERATOR_ROLE =
        keccak256("CHANNEL_OPERATOR_ROLE");

    address public tokenIn;
    address public tokenOut;
    ISwapRouter public uniswapV3Router;

    uint256 public currentSlippage;
    uint24 public poolFee;

    constructor(
        address _tokenIn,
        address _tokenOut,
        address _uniswapV3Router,
        address _channelOperator,
        uint256 _slippage,
        uint24 _poolFee
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHANNEL_OPERATOR_ROLE, _channelOperator);
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
        poolFee = _poolFee;
        currentSlippage = _slippage; // ASSUMPTION: the deploy script won't initialize invalidly.
    }

    function setCurrentSlippage(
        uint256 _newSlippage
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newSlippage > MAX_BPS) {
            revert InvalidSlippage(_newSlippage);
        }
        currentSlippage = _newSlippage;
    }

    function setUniswapV3Router(
        address _newRouter
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapV3Router = ISwapRouter(_newRouter);
    }

    function setTokenIn(
        address _newTokenIn
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenIn = _newTokenIn;
    }

    function setTokenOut(
        address _newTokenOut
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenOut = _newTokenOut;
    }

    function setPoolFee(
        uint24 _newPoolFee
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        poolFee = _newPoolFee;
    }

    function notifySwap(
        uint256 amount,
        address _tokenIn
    ) external override onlyRole(CHANNEL_OPERATOR_ROLE) returns (uint256 amountOut) {
        if (_tokenIn != address(tokenIn)) {
            revert InvalidTokenIn(_tokenIn, address(tokenIn));
        }
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amount,
                // ASSUMPTION: Both tokenIn and tokenOut are stablecoins pegged to the dollar.
                amountOutMinimum: (amount * currentSlippage) / MAX_BPS,
                sqrtPriceLimitX96: 0
            });
        amountOut = uniswapV3Router.exactInputSingle(params);
    }
}
