// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library BaseLib {
    error HasNoRole(address who, bytes32 role);
    error OnlyInternalCall();
    error DelegatedCallsOnly();
    error AlreadyInitialized();
    error UnequalLengths(uint256 length1, uint256 length2);
    error NoElementsFound();
    error IndexOutOfBounds(uint256 index);
    error InvalidOffset(uint256 offset);
    error InvalidAddress(address addr);
    error InBlocklist(address who);
    error MustBeGTZero();

    function enforceInternal() internal view {
        if (msg.sender != address(this)) {
            revert OnlyInternalCall();
        }
    }
}