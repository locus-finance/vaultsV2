// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IDistributionChain {
    event ReceiverAltered(
        address indexed receiver,
        uint256 indexed share,
        bool indexed isBlocked,
        uint256 sumOfShares
    );
    event Distributed(
        uint256 indexed distributedValue,
        uint256 indexed tokensLeftAndSentToOwner
    );

    function addReceiver(address receiver, uint256 share, bool status) external;

    function setReceiverShare(address receiver, uint256 share) external;

    function setReceiverStatus(address receiver, bool status) external;

    function distributeToChain(address token, uint256 amount) external;

    function setReceiverShareAndStatus(
        address receiver,
        uint256 share,
        bool status
    ) external;
}
