// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../diamondBase/facets/BaseFacet.sol";

contract BaseStrategyHandleSomeRequestFacet is BaseFacet {
    function _handleWithdrawSomeRequest(
        WithdrawSomeRequest memory _request
    ) external internalOnly {
        if (withdrawnInEpoch[_request.id]) {
            revert AlreadyWithdrawn();
        }

        (uint256 liquidatedAmount, uint256 loss) = _liquidatePosition(
            _request.amount
        );

        bytes memory payload = abi.encode(
            MessageType.WithdrawSomeResponse,
            WithdrawSomeResponse({
                source: address(this),
                amount: liquidatedAmount,
                loss: loss,
                id: _request.id
            })
        );

        if (liquidatedAmount > 0) {
            _bridge(liquidatedAmount, vaultChainId, vault, payload);
        } else {
            _sendMessageToVault(payload);
        }

        withdrawnInEpoch[_request.id] = true;
    }    
}