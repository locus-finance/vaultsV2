// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSQuoteNotifiableFacet.sol";
import "../../../diamondBase/facets/BaseFacet.sol";
import "./libraries/BSOneInchLib.sol";
import "../../BSLib.sol";

contract BSQuoteNotifiableFacet is BaseFacet, IBSQuoteNotifiableFacet {
    function notifyCallback(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external virtual override internalOnly {
        emit BSOneInchLib.Notified(src, dst, amountOut, amountIn);
    }
}
