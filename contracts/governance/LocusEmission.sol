// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";

import '../interfaces/IGauge.sol';
import "./LocusToken.sol";

contract LocusEmission is AccessControl {
    bytes32 public constant ALLOWED_GAUGE_ROLE = keccak256("ALLOWED_GAUGE_ROLE");

    LocusToken public locusToken;

    constructor(address[] memory allowedGauges) {
        locusToken = new LocusToken();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        for (uint256 i; i < allowedGauges.length; i++) {
            _grantRole(ALLOWED_GAUGE_ROLE, allowedGauges[i]);
        }
    }

    function mintLocus() external onlyRole(ALLOWED_GAUGE_ROLE) {

    }
}