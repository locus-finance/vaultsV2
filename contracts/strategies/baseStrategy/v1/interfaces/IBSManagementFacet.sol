// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBSManagementFacet {
    function setEmergencyExit(bool _emergencyExit) external;

    function setSlippage(uint256 _slippage) external;

    function sweepToken(IERC20 _token) external;

    function revokeFunds() external;

    function clearWant() external;

    function callMe(uint256 epoch) external;

    function setStrategist(address _newStrategist) external;
}
