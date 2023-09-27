// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSAdjustPositionFacet {
    function adjustPosition(uint256 debtOutstanding) external;
}