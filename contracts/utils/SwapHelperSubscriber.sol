// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract SwapHelperSubscriber is AccessControlUpgradeable {
    event Swap(address indexed src, address indexed dst, uint256 indexed amount);
    event Quote(address indexed src, address indexed dst, uint256 indexed amount);
    event Notified(address indexed src, address indexed dst, uint256 indexed amountOut, uint256 amountIn);
    
    event EmergencySwapOnAlternativeDEX(bytes indexed lowLevelErrorData);
    event EmergencyQuoteOnAlternativeDEX(bytes indexed lowLevelErrorData);

    bytes32 public constant QUOTE_OPERATION_PROVIDER =
        keccak256("QUOTE_OPERATION_PROVIDER");
    
    function notifyCallback(address src, address dst, uint256 amountOut, uint256 amountIn) external virtual onlyRole(QUOTE_OPERATION_PROVIDER) {
        emit Notified(src, dst, amountOut, amountIn);
    }
}