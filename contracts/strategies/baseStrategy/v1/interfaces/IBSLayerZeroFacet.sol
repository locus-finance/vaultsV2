// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSLayerZeroFacet {
    error AlreadyWithdrawn();
    error InvalidEndpointCaller(address caller);
    error VaultAddressMismatch(address srcAddress, address vaultAddress);
    error VaultChainIdMismatch(uint16 srcChainId, uint16 vaultChainId);
    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);

    function _initialize(address _lzEndpoint) external;
}