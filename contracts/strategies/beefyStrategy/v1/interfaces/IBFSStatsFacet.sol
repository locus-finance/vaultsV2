// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSStatsFacet.sol";
import "../../BFSLib.sol";

interface IBFSStatsFacet is IBSStatsFacet {
    function getBeefyStrategyPrimitives()
        external
        pure
        returns (BFSLib.Storage memory);

    function balanceOfStaked() external view returns (uint256 amount);
}
