// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct StrategyParams {
    uint256 activation;
    uint256 debtRatio;
    uint256 totalDebt;
    uint256 totalGain;
    uint256 totalLoss;
    uint256 lastReport;
    uint256 performanceFee;
}

struct WithdrawRequest {
    address author;
    address user;
    uint256 shares;
    uint256 maxLoss;
    uint256 expected;
    bool success;
}

struct WithdrawEpoch {
    WithdrawRequest[] requests;
    bool inProgress;
    uint256 approveExpected;
    uint256 approveActual;
    mapping(uint16 => mapping(address => bool)) approved;
    mapping(uint16 => mapping(address => uint256)) requestedAmount;
}

interface IVault {
    error InsufficientFunds(uint256 amount, uint256 balance);

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

    function initialize(
        address _governance,
        address _lzEndpoint,
        IERC20 _token,
        address _sgBridge,
        address _router
    ) external;

    function token() external view returns (IERC20);

    function sweepToken(IERC20 _token) external;

    function revokeFunds() external;

    function totalAssets() external view returns (uint256);

    function deposit(uint256 _amount) external returns (uint256);

    function deposit(
        uint256 _amount,
        address _recipient
    ) external returns (uint256);

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

    function handleWithdrawals() external;

    function pricePerShare() external view returns (uint256);

    function revokeStrategy(uint16 _chainId, address _strategy) external;

    function updateStrategyDebtRatio(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio
    ) external;

    function governance() external view returns (address);
}
