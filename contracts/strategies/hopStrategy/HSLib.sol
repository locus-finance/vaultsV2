// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

import "../diamondBase/libraries/BaseLib.sol";
import "../diamondBase/libraries/InitializerLib.sol";
import "../diamondBase/libraries/PausabilityLib.sol";
import "../diamondBase/libraries/RolesManagementLib.sol";

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library HSLib {
    bytes32 constant HOP_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.hop_strategy");

    struct ReferenceTypes {
        mapping(address => uint256) someMapping;
    }

    struct Primitives {
        uint256 somePrimitive;
    }

    struct Storage {
        ReferenceTypes rt; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE 
        Primitives p; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = HOP_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}