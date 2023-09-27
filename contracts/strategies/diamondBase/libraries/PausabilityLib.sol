// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library PausabilityLib {
    bytes32 constant PAUSABILITY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.locus.pausability");

    struct Storage {
        bool paused;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = PAUSABILITY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}