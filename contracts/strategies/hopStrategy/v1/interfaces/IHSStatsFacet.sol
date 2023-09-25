// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSStatsFacet.sol";
import "../../HSLib.sol";

interface IHSStatsFacet is IBSStatsFacet {
    function getHopStrategyPrimitives()
        external
        pure
        returns (HSLib.Storage memory);

    function updateHopToWantBuffer() external;

    function balanceOfStaked() external view returns (uint256 amount);

    function rewardsEarned() external view returns (uint256 amount);
}
