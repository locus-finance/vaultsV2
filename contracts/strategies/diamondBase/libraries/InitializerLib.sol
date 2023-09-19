// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./BaseLib.sol";

library InitializerLib {
    bytes32 constant INITIALIZER_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.locus.initializer");

    struct Storage {
        bool initialized;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = INITIALIZER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function reset() internal {
        get().initialized = false;
    }

    function initialize() internal {
        if (get().initialized) {
            revert BaseLib.AlreadyInitialized();
        } else {
            get().initialized = true;
        }
    }
}