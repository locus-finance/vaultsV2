// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library BFSLib {
    bytes32 constant BEEFY_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.beefy_strategy");

    struct Storage {
        uint256 some;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = BEEFY_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}