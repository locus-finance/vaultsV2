// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library BaseLib {
    error HasNoRole(address who, bytes32 role);
    error OnlyInternalCall();
    error DelegatedCallsOnly();
    error AlreadyInitialized();
    error UnequalLengths(uint256 length1, uint256 length2);

    function enforceInternal() internal view {
        if (msg.sender != address(this)) {
            revert OnlyInternalCall();
        }
    }
}