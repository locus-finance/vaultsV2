// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IRolesManagement {
    function revokeRoles(address[] calldata entities, bytes32[] calldata roles) external;
    function grantRoles(address[] calldata entities, bytes32[] calldata roles) external;
    function grantRole(address who, bytes32 role) external;
    function revokeRole(address who, bytes32 role) external;
    function hasRole(address who, bytes32 role) external view returns (bool);
}