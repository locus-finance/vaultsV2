// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSQuoteNotifiableFacet.sol";

interface IPSUtilsFacet is IBSQuoteNotifiableFacet {
    function claimAndSellRewards() external;
}
