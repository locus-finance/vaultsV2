// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSQuoteNotifiableFacet.sol";

interface IHSUtilsFacet is IBSQuoteNotifiableFacet {
    function claimAndSellRewards() external;

    function lpToWant(
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function hopToWant(uint256 amountIn) external;

    function sellHopForWant(uint256 amountToSell) external;
}
