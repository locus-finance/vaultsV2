// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../DHLib.sol";

interface IDistributionChainLoupe {
    function getReceiversByAddresses(
        uint256 offset,
        uint256 windowSize,
        address[] memory addresses
    ) external view returns (uint256[] memory indicies);

    function getReceiversByShares(
        uint256 offset,
        uint256 windowSize,
        uint256[] memory shares
    ) external view returns (uint256[] memory indicies);

    function getReceiversByStatus(
        uint256 offset,
        uint256 windowSize,
        bool status
    ) external view returns (uint256[] memory indicies);

    function getReceiverByIdx(
        uint256 idx
    ) external view returns (DHLib.Receiver memory);

    function getSumOfShares() external view returns (uint256);
}
