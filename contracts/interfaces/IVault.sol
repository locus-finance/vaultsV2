// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

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

    function token() external view returns (IERC20);

    function totalAssets() external view returns (uint256, uint256);

    function addStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee
    ) external;

    function initiateDeposit(uint256 _amount) external;

    function initiateWithdraw(uint256 _shares, uint256 _maxLoss) external;

    function handleDeposits() external;

    function handleWithdrawals() external;

    function viewStrategy(
        uint16 _chainId,
        address _strategy
    ) external view returns (StrategyParams memory);

    function pricePerShare() external view returns (uint256);

    function revokeStrategy(uint16 _chainId, address _strategy) external;

    function governance() external view returns (address);
}
