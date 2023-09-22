// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSSwapHelperFacet {
    function quote(address src, address dst, uint256 amount) external;
    
    function swap(address src, address dst, uint256 amount, uint256 slippage) external;
}
