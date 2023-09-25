// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library PSLib {
    bytes32 constant PEARL_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.pearl_strategy");

    struct Storage {
        uint256 requestedQuoteHopToWant;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = PEARL_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}