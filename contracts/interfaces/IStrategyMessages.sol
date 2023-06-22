// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IStrategyMessages {
    enum MessageType {
        ReportTotalAssetsResponse,
        WithdrawSomeRequest,
        WithdrawSomeResponse,
        WithdrawAllRequest,
        WithdrawAllResponse
    }

    struct ReportTotalAssetsResponse {
        uint256 timestamp;
        uint256 totalAssets;
    }

    struct WithdrawSomeRequest {
        uint256 amount;
        uint256 id;
    }

    struct WithdrawSomeResponse {
        uint256 amount;
        uint256 loss;
        uint256 id;
    }

    struct WithdrawAllRequest {
        uint256 id;
    }

    struct WithdrawAllResponse {
        uint256 amount;
        uint256 id;
    }
}
