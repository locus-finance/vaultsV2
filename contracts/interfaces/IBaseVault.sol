// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;


interface IBaseVault {

    function pricePerShare() external view returns (uint256);
}
