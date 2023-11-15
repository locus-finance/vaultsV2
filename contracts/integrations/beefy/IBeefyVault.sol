// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBeefyVault is IERC20 {
    function deposit(uint _amount) external;
    function withdraw(uint256 _shares) external;
    function getPricePerFullShare() external view returns (uint256);
}