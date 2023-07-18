// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct StrategyParams {
    uint256 performanceFee;
    uint256 activation;
    uint256 debtRatio;
    uint256 totalDebt;
    uint256 totalGain;
    uint256 totalLoss;
    uint256 lastReport;
    uint256 lastReportedTotalAssets;
}

struct DepositRequest {
    address user;
    uint256 amount;
}

struct WithdrawRequest {
    address user;
    uint256 shares;
    uint256 maxLoss;
}

struct DepositEpoch {
    DepositRequest[] requests;
}

struct WithdrawEpoch {
    WithdrawRequest[] requests;
    bool inProgress;
    uint256 approveExpected;
    uint256 approveActual;
}

interface IVault {
    error InsufficientFunds(uint256 amount, uint256 balance);

    event SgReceived(address indexed token, uint256 amount, address sender);
    event StrategyWithdrawnAll(
        uint16 indexed chainId,
        address indexed strategy,
        uint256 amount,
        uint256 id
    );
    event StrategyWithdrawnSome(
        uint16 indexed chainId,
        address indexed strategy,
        uint256 amount,
        uint256 loss,
        uint256 id
    );
    event StrategyReportedAssets(
        uint16 indexed chainId,
        address indexed strategy,
        uint256 timestamp,
        uint256 totalAssets
    );
    event FulfilledDepositEpoch(uint256 epochId, uint256 requestCount);
    event FulfilledWithdrawEpoch(uint256 epochId, uint256 requestCount);

    function initialize(
        address _governance,
        address _lzEndpoint,
        IERC20 _token,
        address _sgBridge,
        address _router
    ) external;

    function token() external view returns (IERC20);

    function revokeFunds() external;

    function totalAssets() external view returns (uint256, uint256);

    function deposit(uint256 _amount) external;

    function deposit(uint256 _amount, address _recipient) external;

    function withdraw() external;

    function withdraw(uint256 _maxShares, uint256 _maxLoss) external;

    function withdraw(
        uint256 _maxShares,
        address _recipient,
        uint256 _maxLoss
    ) external;

    function addStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee
    ) external;

    function handleDeposits() external;

    function handleWithdrawals() external;

    function pricePerShare() external view returns (uint256);

    function revokeStrategy(uint16 _chainId, address _strategy) external;

    function cancelWithdrawalEpoch(uint256 _epochId) external;

    function requestReportFromStrategy(
        uint16 _chainId,
        address _strategy
    ) external;

    function feeForWithdrawRequestFromStrategy(
        uint16 _destChainId
    ) external view returns (uint256);

    function governance() external view returns (address);
}
