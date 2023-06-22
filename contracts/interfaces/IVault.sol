// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

struct StrategyParams {
    uint256 performanceFee;
    uint256 activation;
    uint256 debtRatio;
    uint256 lastReport;
    uint256 totalDebt;
    uint256 totalGain;
    uint256 totalLoss;
    uint256 lastReportedTotalAssets;
}

interface IVault is IERC4626 {
    function name() external view returns (string calldata);

    function symbol() external view returns (string calldata);

    function initialize(
        address token,
        address governance,
        address rewards,
        string memory name,
        string memory symbol
    ) external;

    function addStrategy(
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee
    ) external;

    function token() external view returns (address);

    function handleWithdrawals() external;

    function strategies(
        address _strategy
    ) external view returns (StrategyParams memory);

    function pricePerShare() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function revokeStrategy(address strategy) external;

    function governance() external view returns (address);
}
