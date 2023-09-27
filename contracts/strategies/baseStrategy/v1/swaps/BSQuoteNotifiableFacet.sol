// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSQuoteNotifiableFacet.sol";
import "../../../diamondBase/facets/BaseFacet.sol";
import "../../BSLib.sol";

contract BSQuoteNotifiableFacet is BaseFacet, IBSQuoteNotifiableFacet {
    event QuoteNotified(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );

    function notifyCallback(
        address src,
        address dst,
        uint256 amountOut,
        uint256 amountIn
    ) external virtual override internalOnly {
        emit QuoteNotified(src, dst, amountOut, amountIn);
    }
}
