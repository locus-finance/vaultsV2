// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

library RolesManagementLib {
    error HasNoRole(address who, bytes32 role);
    error HasNoRoles(address who, bytes32[] roles);

    bytes32 constant ROLES_MANAGEMENT_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.locus.roles");

    // roles to check with EOA
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    bytes32 public constant OWNER_ROLE = keccak256('OWNER_ROLE');

    // A special role - must not be removed.
    bytes32 public constant INTERNAL_ROLE = keccak256('INTERNAL_ROLE');

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
        if (role == INTERNAL_ROLE) {
            if (who != address(this)) {
                revert HasNoRole(who, INTERNAL_ROLE);
            }
        } else if (!get().roles[role][who]) {
            revert HasNoRole(who, role);
        }
        
    }

    function hasRole(address who, bytes32 role) internal view returns(bool) {
        return get().roles[role][who];
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

    function enforceEitherOfRoles(address who, bytes32[] memory roles) internal view {
        bool result;
        for (uint256 i = 0; i < roles.length; i++) {
            if (roles[i] == INTERNAL_ROLE) {
                result = result || who == address(this);
            } else {
                result = result || get().roles[roles[i]][who];
            }
        }
        if (!result) {
            revert HasNoRoles(who, roles);
        }
    }

    function enforceSenderEitherOfRoles(bytes32[] memory roles) internal view {
        enforceEitherOfRoles(msg.sender, roles);
    }
}