// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../interfaces/ISwapHelper.sol";

struct SwapHelperDTO {
    ISwapHelper swapHelper;
    uint256 quoteBuffer;
    bool isQuoteBufferContainsHopToWantValue;
}

abstract contract SwapHelperUser {
    error SwapHelperOnly();

    event Swap(address indexed src, address indexed dst, uint256 indexed amount);
    event Quote(address indexed src, address indexed dst, uint256 indexed amount);
    event Notified(address indexed src, address indexed dst, uint256 indexed amountOut, uint256 amountIn);
    
    event EmergencySwapOnAlternativeDEX(address indexed src, address indexed dst, uint256 indexed amount, bytes lowLevelErrorData);
    event EmergencyQuoteOnAlternativeDEX(address indexed src, address indexed dst, uint256 indexed amount, bytes lowLevelErrorData);

    modifier onlySwapHelper {
        if (msg.sender != address(_swapHelperDTO.swapHelper)) {
            revert SwapHelperOnly();
        }
        _;
    }

    SwapHelperDTO internal _swapHelperDTO;
    
    function _quoteEventEmitter(
        address tokenFrom, 
        address tokenTo, 
        uint256 amount, 
        bytes memory errorData
    ) internal {
        if (errorData.length == 0) {
            emit Quote(tokenFrom, tokenTo, amount);
        } else {
            emit EmergencyQuoteOnAlternativeDEX(tokenFrom, tokenTo, amount, errorData);
        }
    }

    function _swapEventEmitter(
        address tokenFrom, 
        address tokenTo, 
        uint256 amount, 
        bytes memory errorData
    ) internal {
        if (errorData.length == 0) {
            emit Swap(tokenFrom, tokenTo, amount);
        } else {
            emit EmergencySwapOnAlternativeDEX(tokenFrom, tokenTo, amount, errorData);
        }
    }

    function notifyCallback(address src, address dst, uint256 amountOut, uint256 amountIn) external virtual onlySwapHelper {
        emit Notified(src, dst, amountOut, amountIn);
    }
}