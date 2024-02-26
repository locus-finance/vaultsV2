// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct StrategyParams {
    uint256 activation;
    uint256 debtRatio;
    uint256 totalDebt;
    uint256 totalGain;
    uint256 totalLoss;
    uint256 lastReport;
    uint256 performanceFee;
    address strategist;
}

struct WithdrawRequest {
    address author;
    address user;
    uint256 shares;
    uint256 maxLoss;
    uint256 expected;
    bool success;
    uint256 timestamp;
}

struct WithdrawEpoch {
    WithdrawRequest[] requests;
    bool inProgress;
    uint256 approveExpected;
    uint256 approveActual;
}

interface IVault {
    error InsufficientFunds(uint256 amount, uint256 balance);
    error Vault__V1();
    error Vault__V2();
    error Vault__V3();
    error Vault__V4();
    error Vault__V5();
    error Vault__V6();
    error Vault__V7();
    error Vault__V8();
    error Vault__V9();
    error Vault__V10();
    error Vault__V11();
    error Vault__V12();
    error Vault__V13();
    error Vault__V14();
    error Vault__V15();
    error Vault__V16();
    error Vault__V17();
    error Vault__V18();
    error Vault__V19();
    error Vault__V20();
    error Vault__V21();
    error Vault__V22();
    error Vault__V23();

    event SgReceived(address indexed token, uint256 amount, address sender);
    event StrategyWithdrawnSome(
        uint16 indexed chainId,
        address indexed strategy,
        uint256 amount,
        uint256 loss,
        uint256 id
    );
    event FulfilledWithdrawEpoch(uint256 epochId, uint256 requestCount);
    event StrategyReported(
        uint16 chainId,
        address strategy,
        uint256 gain,
        uint256 loss,
        uint256 debtPaid,
        uint256 totalGain,
        uint256 totalLoss,
        uint256 totalDebt,
        uint256 debtAdded,
        uint256 debtRatio,
        uint256 tokens
    );
    event Deposit(address indexed from, uint256 indexed wantTokenAmount, address indexed recipient, uint256 sharesIssued, uint256 timestamp);
    event Withdraw(address indexed from, uint256 indexed wantTokenAmount, address indexed recipient, uint256 sharesIssued, uint256 timestamp);
}
