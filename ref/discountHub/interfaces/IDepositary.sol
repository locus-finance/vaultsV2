// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDepositary {
    event Deposit(address token, address depositee, uint256 amount);
    event Withdraw(address token, address depositee, uint256 amount);
    event Transform(address newDepositee, uint256 amount);

    function deposit(IERC20 token, address depositee, uint256 amount) external;

    function withdraw(
        IERC20 token,
        uint256 amount,
        address from,
        address recipient
    ) external;

    function transformDeposit(address to, uint256 amount) external;
}
