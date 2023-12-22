// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../integrations/uniswap/IV3SwapRouter.sol";
import "../interfaces/ISwapChannel.sol";

contract SwapChannel is ISwapChannel, AccessControl {
    error InvalidSlippage(uint256 value);
    error NotEnough(address token, uint256 value, uint256 delta);

    uint256 public constant MAX_BPS = 10000;
    bytes32 public constant CHANNEL_OPERATOR_ROLE =
        keccak256("CHANNEL_OPERATOR_ROLE");

    IERC20 public tokenIn;
    IERC20 public tokenOut;
    IV3SwapRouter public uniswapV3Router;

    uint256 public currentSlippage;

    constructor(
        address _tokenIn,
        address _tokenOut,
        address _uniswapV3Router,
        address _channelOperator,
        uint256 _slippage
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHANNEL_OPERATOR_ROLE, _channelOperator);
        tokenIn = IERC20(_tokenIn);
        tokenOut = IERC20(_tokenOut);
        uniswapV3Router = IV3SwapRouter(_uniswapV3Router);
        setCurrentSlippage(_slippage);
    }

    function setCurrentSlippage(
        uint256 _newSlippage
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newSlippage > MAX_BPS) {
            revert InvalidSlippage(_newSlippage);
        }
        currentSlippage = _newSlippage;
    }

    function notifySwap(
        uint256 amount
    ) external override onlyRole(CHANNEL_OPERATOR_ROLE) {
        
    }
}
