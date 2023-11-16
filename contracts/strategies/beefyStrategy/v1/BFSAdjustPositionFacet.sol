// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSAdjustPositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../BFSLib.sol";
import "./interfaces/IBFSUtilsFacet.sol";
import "./interfaces/IBFSStatsFacet.sol";

contract BFSAdjustPositionFacet is BaseFacet, IBSAdjustPositionFacet {
    function adjustPosition(
        uint256 _debtOutstanding
    ) external override internalOnly {
        
    }
}
