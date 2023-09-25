// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";

import "./interfaces/IPSStatsFacet.sol";
import "../../baseStrategy/v1/BSStatsFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "../PSLib.sol";

contract PSStatsFacet is BSStatsFacet, IPSStatsFacet {
    function getPearlStrategyPrimitives()
        external
        pure
        override
        returns (PSLib.Storage memory)
    {
        return PSLib.get();
    }

    function name()
        external
        pure
        override(BSStatsFacet, IBSStatsFacet)
        returns (string memory)
    {
        return "PearlStrategy";
    }

    function estimatedTotalAssets()
        public
        view
        override(BSStatsFacet, IBSStatsFacet)
        delegatedOnly
        returns (uint256)
    {
        return 0;
    }
}
