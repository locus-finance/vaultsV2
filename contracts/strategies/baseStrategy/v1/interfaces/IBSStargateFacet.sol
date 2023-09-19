// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSStargateFacet {
    error RouterOrBridgeOnly();
    event SgReceived(address indexed token, uint256 amount, address sender);

    function bridge(
        uint256 _amount,
        uint16 _destChainId,
        address _dest,
        bytes memory _payload
    ) external;
}
