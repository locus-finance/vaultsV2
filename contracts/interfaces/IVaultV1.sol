// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVaultV1 {
    function token() external view returns (IERC20);

    function withdraw() external returns (uint256);
}
