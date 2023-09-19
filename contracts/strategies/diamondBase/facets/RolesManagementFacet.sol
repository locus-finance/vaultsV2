// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../libraries/BaseLib.sol";
import "../libraries/RolesManagementLib.sol";
import "../interfaces/IRolesManagement.sol";
import "./BaseFacet.sol";

contract RolesManagementFacet is IRolesManagement, BaseFacet {
    function grantRoles(address[] calldata people, bytes32[] calldata roles) 
        external 
        override 
        delegatedOnly
    {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.INITIALIZER_ROLE);
        if (people.length != roles.length) {
            revert BaseLib.UnequalLengths(people.length, roles.length);
        }
        for (uint256 i = 0; i < people.length; i++) {
            RolesManagementLib.grantRole(people[i], roles[i]);
        }
    }

    function revokeRoles(address[] calldata people, bytes32[] calldata roles) 
        external 
        override 
        delegatedOnly
    {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.INITIALIZER_ROLE);
        if (people.length != roles.length) {
            revert BaseLib.UnequalLengths(people.length, roles.length);
        }
        for (uint256 i = 0; i < people.length; i++) {
            RolesManagementLib.revokeRole(people[i], roles[i]);
        }
    }
    
    function grantRole(address who, bytes32 role) public override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.INITIALIZER_ROLE);
        RolesManagementLib.grantRole(who, role);
    }

    function revokeRole(address who, bytes32 role) public override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.INITIALIZER_ROLE);
        RolesManagementLib.revokeRole(who, role);
    }

    function hasRole(address who, bytes32 role) public view override delegatedOnly returns(bool) {
        return RolesManagementLib.get().roles[role][who];
    }
}