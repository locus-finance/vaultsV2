// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSStatsFacet.sol";
import "../../PSLib.sol";

interface IPSStatsFacet is IBSStatsFacet {
    function getPearlStrategyPrimitives()
        external
        pure
        returns (PSLib.Storage memory);
}
