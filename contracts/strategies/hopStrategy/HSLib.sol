// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

import "../base/libraries/BaseLib.sol";
import "../base/libraries/InitializerLib.sol";
import "../base/libraries/PausabilityLib.sol";
import "../base/libraries/RolesManagementLib.sol";

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library HSLib {
    bytes32 constant HOP_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.discount_hub");

    uint256 public constant MAX_BPS = 10000;

    struct StorageMappings {
        mapping(address => uint256) someMapping;
    }

    struct StoragePrimitives {
        uint256 somePrimitive;
    }

    struct Storage {
        StorageMappings mappings;
        StoragePrimitives primitives;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = HOP_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}