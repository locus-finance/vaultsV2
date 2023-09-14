// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../interfaces/IDistributionChainLoupe.sol";
import "./base/DHBaseFacet.sol";

contract DistributionChainLoupeFacet is DHBaseFacet, IDistributionChainLoupe {
    function getReceiversByAddresses(
        uint256 offset,
        uint256 windowSize,
        address[] memory addresses
    ) external view override delegatedOnly returns (uint256[] memory indicies) {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 receiversLength = s.receivers.length;
        if (offset >= receiversLength) {
            revert BaseLib.InvalidOffset(offset);
        }
        indicies = new uint256[](windowSize);
        uint256 coursor;
        for (uint256 i = offset; i < receiversLength; i++) {
            for (uint256 j = 0; j < addresses.length; j++) {
                if (s.receivers[i].receiver == addresses[j]) {
                    indicies[coursor++] = i;
                }
            }
        }
        if (coursor == 0) revert BaseLib.NoElementsFound();
    }

    function getReceiversByShares(
        uint256 offset,
        uint256 windowSize,
        uint256[] memory shares
    ) external view override delegatedOnly returns (uint256[] memory indicies) {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 receiversLength = s.receivers.length;
        if (offset >= receiversLength) {
            revert BaseLib.InvalidOffset(offset);
        }
        indicies = new uint256[](windowSize);
        uint256 coursor;
        for (uint256 i = offset; i < receiversLength; i++) {
            for (uint256 j = 0; j < shares.length; j++) {
                if (s.receivers[i].share == shares[j]) {
                    indicies[coursor++] = i;
                }
            }
        }
        if (coursor == 0) revert BaseLib.NoElementsFound();
    }

    function getReceiversByStatus(
        uint256 offset,
        uint256 windowSize,
        bool status
    ) external view override delegatedOnly returns (uint256[] memory indicies) {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        uint256 receiversLength = s.receivers.length;
        if (offset >= receiversLength) {
            revert BaseLib.InvalidOffset(offset);
        }
        indicies = new uint256[](windowSize);
        uint256 coursor;
        for (uint256 i = offset; i < receiversLength; i++) {
            if (s.receivers[i].isBlocked == status) {
                indicies[coursor++] = i;
            }
        }
        if (coursor == 0) revert BaseLib.NoElementsFound();
    }

    function getReceiverByIdx(
        uint256 idx
    ) external view override delegatedOnly returns (DHLib.Receiver memory) {
        DHLib.StoragePrimitives storage s = DHLib.get().primitives;
        if (idx >= s.receivers.length) {
            revert BaseLib.IndexOutOfBounds(idx);
        }
        return s.receivers[idx];
    }

    function getSumOfShares()
        external
        view
        override
        delegatedOnly
        returns (uint256)
    {
        return DHLib.get().primitives.sumOfShares;
    }
}
