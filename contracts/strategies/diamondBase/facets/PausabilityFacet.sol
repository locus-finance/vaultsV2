// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/IPausable.sol";
import "../libraries/PausabilityLib.sol";
import "../libraries/RolesManagementLib.sol";
import "./BaseFacet.sol";

contract PausabilityFacet is IPausable, BaseFacet {
    function paused() external view override delegatedOnly returns (bool) {
        return PausabilityLib.get().paused;
    }

    function pause() external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.PAUSER_ROLE);
        PausabilityLib.get().paused = true;
    }

    function unpause() external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.PAUSER_ROLE);
        PausabilityLib.get().paused = false;
    }
}