// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSUtilsFacet {
    error InvalidSignature();

    function strategistSignMessageHash() external view returns (bytes32);

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) external pure returns (bytes32);

    function withSlippage(uint256 _amount) external view returns (uint256);

    function withSlippage(
        uint256 _amount,
        uint256 _slippage
    ) external pure returns (uint256);

    function verifySignature(bytes memory _signature) external view;
}
