// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../libraries/PausabilityLib.sol";
import "../libraries/InitializerLib.sol";
import "../libraries/RolesManagementLib.sol";

abstract contract BaseFacet {
    error DelegatedCallsOnly();
    
    /// @dev An address of the actual contract instance. The original address as part of the context.
    address internal immutable __self = address(this);

    function enforceDelegatedOnly() internal view {
        if (address(this) == __self || !InitializerLib.get().initialized) {
            revert DelegatedCallsOnly();
        }
    }

    /// @dev The body of the modifier is copied into a faucet sources, so to make a small gas
    /// optimization - the modifier uses an internal function call.
    modifier delegatedOnly {
        enforceDelegatedOnly();
        _;
    }

    modifier internalOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.INTERNAL_ROLE);
        _;
    }
}