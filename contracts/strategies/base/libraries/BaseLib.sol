// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library BaseLib {
    error HasNoRole(address who, bytes32 role);
    error OnlyInternalCall();
    error DelegatedCallsOnly();
    error AlreadyInitialized();

    function enforceInternal() internal view {
        if (msg.sender != address(this)) {
            revert OnlyInternalCall();
        }
    }
}