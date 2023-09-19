// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBSManagementFacet.sol";
import "../../diamondBase/libraries/RolesManagementLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSManagementFacet is BaseFacet, IBSManagementFacet {
    function setEmergencyExit(bool _emergencyExit) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        emergencyExit = _emergencyExit;
    }

    function setSlippage(uint256 _slippage) external override {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        slippage = _slippage;
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