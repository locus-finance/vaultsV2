// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library BaseLib {
    error OnlyInternalCall();
    error NotImplemented();
    
    function enforceInternal() internal view {
        if (msg.sender != address(this)) {
            revert OnlyInternalCall();
        }
    }
}