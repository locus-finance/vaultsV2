// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSLayerZeroFacet {
    error AlreadyWithdrawn();
    error InvalidEndpointCaller(address caller);
    error VaultAddressMismatch(address srcAddress, address vaultAddress);
    error VaultChainIdMismatch(uint16 srcChainId, uint16 vaultChainId);
    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);

    /// @dev Naming convention is violated due to internal nature of the function. 
    /// Basically the function should be marked `internalOnly` and should be
    /// called specifically in the initialization function of the concrete strategy diamond.
    function _initialize(address _lzEndpoint) external;
    function sendMessageToVault(bytes memory _payload) external;
}
