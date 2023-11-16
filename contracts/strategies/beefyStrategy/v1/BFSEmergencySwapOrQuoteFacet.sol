// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSEmergencySwapOrQuoteFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";

contract BFSEmergencySwapOrQuoteFacet is BaseFacet, IBSEmergencySwapOrQuoteFacet {
    function emergencyRequestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override internalOnly returns (uint256 amountOut) {}

    function emergencyRequestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override internalOnly {}
}