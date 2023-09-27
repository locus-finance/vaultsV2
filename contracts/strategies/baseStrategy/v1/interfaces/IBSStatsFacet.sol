// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../BSLib.sol";

interface IBSStatsFacet {
    function name() external view returns (string memory);

    function estimatedTotalAssets() external view returns (uint256);

    function balanceOfWant() external view returns (uint256);

    function getBaseStrategyPrimitives() external view returns (BSLib.Primitives memory);
}
