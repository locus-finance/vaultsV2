// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "../../DHLib.sol";
import "../../../base/libraries/RolesManagementLib.sol";
import "../../../base/facets/BaseFacet.sol";

abstract contract DHBaseFacet is BaseFacet {
    function _checkIfIsInBlocklist(address who) internal view {
        if (
            IAccessControl(DHLib.get().primitives.depositeeBlocklist).hasRole(
                keccak256("BLOCKLISTED_ROLE"),
                who
            )
        ) {
            revert BaseLib.InBlocklist(who);
        }
    }
}