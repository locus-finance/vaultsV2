// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBaseStrategyLayerZeroFacet {
    error AlreadyWithdrawn();
    error InvalidEndpointCaller(address caller);
    error VaultAddressMismatch(address srcAddress, address vaultAddress);
    error VaultChainIdMismatch(uint16 srcChainId, uint16 vaultChainId);
    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);

    event SgReceived(address indexed token, uint256 amount, address sender);
    event StrategyReported(
        uint256 profit,
        uint256 loss,
        uint256 debtPayment,
        uint256 giveToStrategy,
        uint256 requestFromStrategy,
        uint256 creditAvailable,
        uint256 totalAssets
    );
    event AdjustedPosition(uint256 debtOutstanding);
    event StrategyMigrated(address newStrategy);
}