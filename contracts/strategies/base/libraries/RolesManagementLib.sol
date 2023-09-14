// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

import "./BaseLib.sol";

library RolesManagementLib {
    bytes32 constant ROLES_MANAGEMENT_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.locus.roles");

    // roles to check with EOA
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    bytes32 public constant AUTHORITY_ROLE = keccak256('AUTHORITY_ROLE');
    bytes32 public constant DEPOSITEE_ROLE = keccak256('DEPOSITEE_ROLE');
    bytes32 public constant INITIALIZER_ROLE = keccak256('INITIALIZER_ROLE');
    bytes32 public constant CUSTODIAL_MANAGER_ROLE = keccak256('CUSTODIAL_MANAGER_ROLE');

    // roles to check with smart-contracts
    bytes32 public constant ALLOWED_TOKEN_ROLE = keccak256('ALLOWED_TOKEN_ROLE');

    struct Storage {
        mapping(bytes32 => mapping(address => bool)) roles;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = ROLES_MANAGEMENT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function enforceRole(address who, bytes32 role) internal view {
        if (!get().roles[role][who]) {
            revert BaseLib.HasNoRole(who, role);
        }
    }

    function enforceSenderRole(bytes32 role) internal view {
        enforceRole(msg.sender, role);
    }

    function grantRole(address who, bytes32 role) internal {
        get().roles[role][who] = true; 
    }

    function revokeRole(address who, bytes32 role) internal {
        get().roles[role][who] = false; 
    }
}