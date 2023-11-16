// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";

import "./interfaces/IBFSStatsFacet.sol";
import "../../baseStrategy/v1/BSStatsFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IBFSUtilsFacet.sol";
import "../BFSLib.sol";

contract BFSStatsFacet is BSStatsFacet, IBFSStatsFacet {
    function getBeefyStrategyPrimitives()
        external
        pure
        override
        returns (BFSLib.Storage memory)
    {
        return BFSLib.get();
    }

    function name()
        external
        pure
        override(BSStatsFacet, IBSStatsFacet)
        returns (string memory)
    {
        return "BeefyStrategy";
    }

    function estimatedTotalAssets()
        public
        view
        override(BSStatsFacet, IBSStatsFacet)
        delegatedOnly
        returns (uint256)
    {
    }

    function balanceOfStaked()
        public
        view
        override
        delegatedOnly
        returns (uint256 amount)
    {
    }
}
