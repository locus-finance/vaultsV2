// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IStrategyMessages {
    enum MessageType {
        WithdrawSomeRequest,
        WithdrawSomeResponse,
        StrategyReport,
        AdjustPositionRequest
    }

    struct WithdrawSomeRequest {
        uint256 amount;
        uint256 id;
    }

    struct WithdrawSomeResponse {
        address source;
        uint256 amount;
        uint256 loss;
        uint256 id;
    }

    struct StrategyReport {
        address strategy;
        uint256 timestamp;
        uint256 profit;
        uint256 loss;
        uint256 debtPayment;
        uint256 giveToStrategy;
        uint256 requestFromStrategy;
        uint256 creditAvailable;
        uint256 totalAssets;
    }

    struct AdjustPositionRequest {
        uint256 debtOutstanding;
    }
}
