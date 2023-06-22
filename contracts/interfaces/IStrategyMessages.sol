// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IStrategyMessages {
    enum MessageType {
        ReportTotalAssets
    }

    struct ReportTotalAssetsMessage {
        uint256 timestamp;
        uint256 totalAssets;
    }
}
