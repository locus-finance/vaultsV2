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

interface IVault {
    event SgReceived(address indexed token, uint256 amount, address sender);

    function totalAssets() external view returns (uint256, uint256);

    function addStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee
    ) external;

    function token() external view returns (IERC20);

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
