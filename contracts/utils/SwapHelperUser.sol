// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../interfaces/ISwapHelper.sol";

struct SwapHelperDTO {
    ISwapHelper swapHelper;
    uint256 quoteBuffer;
    bool isQuoteBufferContainsHopToWantValue;
}

abstract contract SwapHelperUser is AccessControlUpgradeable {
    SwapHelperDTO internal _swapHelperDTO;
    
    event Swap(address indexed src, address indexed dst, uint256 indexed amount);
    event Quote(address indexed src, address indexed dst, uint256 indexed amount);
    event Notified(address indexed src, address indexed dst, uint256 indexed amountOut, uint256 amountIn);
    
    event EmergencySwapOnAlternativeDEX(address indexed src, address indexed dst, uint256 indexed amount, bytes lowLevelErrorData);
    event EmergencyQuoteOnAlternativeDEX(address indexed src, address indexed dst, uint256 indexed amount, bytes lowLevelErrorData);

    bytes32 public constant QUOTE_OPERATION_PROVIDER =
        keccak256("QUOTE_OPERATION_PROVIDER");
    
    function notifyCallback(address src, address dst, uint256 amountOut, uint256 amountIn) external virtual onlyRole(QUOTE_OPERATION_PROVIDER) {
        emit Notified(src, dst, amountOut, amountIn);
    }
}