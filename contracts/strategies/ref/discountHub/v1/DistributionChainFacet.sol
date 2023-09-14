// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../interfaces/IDistributionChain.sol";
import "./base/DHBaseFacet.sol";

contract DistributionChainFacet is DHBaseFacet, IDistributionChain {
    using SafeERC20 for IERC20;

    function addReceiver(
        address receiver,
        uint256 share,
        bool status
    ) external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(
            RolesManagementLib.INITIALIZER_ROLE
        );
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        s.receivers.push(
            DHLib.Receiver({
                previousShare: 0,
                share: share,
                receiver: receiver,
                isBlocked: status
            })
        );
        s.sumOfShares += share;
        emit ReceiverAltered(receiver, share, status, s.sumOfShares);
    }

    function setReceiverShare(
        address receiver,
        uint256 share
    ) public override delegatedOnly onlyOwner {
        if (share == 0) {
            revert BaseLib.MustBeGTZero();
        }
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 receiversLength = s.receivers.length;
        for (uint256 i = 0; i < receiversLength; i++) {
            DHLib.Receiver storage containedReceiver = s.receivers[i];
            if (containedReceiver.receiver == receiver) {
                uint256 containedReceiverShare = containedReceiver.share;
                if (containedReceiverShare != share) {
                    if (containedReceiverShare > share) {
                        s.sumOfShares -= containedReceiverShare - share;
                    } else {
                        s.sumOfShares += share - containedReceiverShare;
                    }
                    containedReceiver.share = share;
                }
                emit ReceiverAltered(
                    receiver,
                    share,
                    containedReceiver.isBlocked,
                    s.sumOfShares
                );
                return;
            }
        }
    }

    function setReceiverShareAndStatus(
        address receiver,
        uint256 share,
        bool status
    ) external override {
        setReceiverShare(receiver, share);
        setReceiverStatus(receiver, status);
    }

    function setReceiverStatus(
        address receiver,
        bool status
    ) public override delegatedOnly onlyOwner {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 receiversLength = s.receivers.length;
        for (uint256 i = 0; i < receiversLength; i++) {
            DHLib.Receiver storage containedReceiver = s.receivers[i];
            if (containedReceiver.receiver == receiver) {
                if (containedReceiver.isBlocked != status) {
                    containedReceiver.isBlocked = status;
                    if (status) {
                        uint256 previousShare = containedReceiver.share;
                        containedReceiver.previousShare = previousShare;
                        containedReceiver.share = 0;
                        s.sumOfShares -= previousShare;
                    } else {
                        uint256 _share = containedReceiver.previousShare;
                        containedReceiver.previousShare = 0;
                        containedReceiver.share = _share;
                        s.sumOfShares += _share;
                    }
                }
                emit ReceiverAltered(
                    receiver,
                    containedReceiver.share,
                    status,
                    s.sumOfShares
                );
                return;
            }
        }
    }

    function distributeToChain(
        address token,
        uint256 amount
    ) external override internalOnly {
        uint256 remaining = amount;
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 sumOfShares = s.sumOfShares;
        uint256 receiversLength = s.receivers.length;
        for (uint256 i = 0; i < receiversLength; i++) {
            DHLib.Receiver storage containedReceiver = s.receivers[i];
            if (!containedReceiver.isBlocked) {
                uint256 receiversShare = (amount * containedReceiver.share) /
                    sumOfShares;
                remaining -= receiversShare;
                IERC20(token).safeTransfer(
                    containedReceiver.receiver,
                    receiversShare
                );
            }
        }
        if (remaining > 0) {
            IERC20(token).safeTransfer(LibDiamond.contractOwner(), remaining);
        }
        emit Distributed(amount, remaining);
    }
}
