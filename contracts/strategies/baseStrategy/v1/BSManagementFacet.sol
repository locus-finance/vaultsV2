// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBSManagementFacet.sol";
import "../../diamondBase/libraries/RolesManagementLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSManagementFacet is BaseFacet, IBSManagementFacet {
    using SafeERC20 for IERC20;

    function setStrategist(address _newStrategist) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.OWNER_ROLE);
        address oldStrategist = BSLib.get().p.strategist;
        if (oldStrategist != address(0)) {
            RolesManagementLib.revokeRole(oldStrategist, RolesManagementLib.STRATEGIST_ROLE);
        }
        RolesManagementLib.grantRole(_newStrategist, RolesManagementLib.STRATEGIST_ROLE);
        BSLib.get().p.strategist = _newStrategist;
    }

    function setEmergencyExit(bool _emergencyExit) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        BSLib.get().p.emergencyExit = _emergencyExit;
    }

    function setSlippage(uint256 _slippage) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        BSLib.get().p.slippage = _slippage;
    }

    function sweepToken(IERC20 _token) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        _token.safeTransfer(msg.sender, _token.balanceOf(address(this)));
    }

    function revokeFunds() external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        payable(msg.sender).transfer(address(this).balance);
    }

    // ** DEBUG FUNCTIONS **

    function clearWant() external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        IERC20 want = BSLib.get().p.want;
        want.safeTransfer(address(1), want.balanceOf(address(this)));
    }

    function callMe(uint256 epoch) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.OWNER_ROLE);
        BSLib.get().rt.withdrawnInEpoch[epoch] = false;
    }
}