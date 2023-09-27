// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IBSStatsFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSStatsFacet is BaseFacet, IBSStatsFacet {
    function getBaseStrategyPrimitives()
        external
        view
        virtual
        override
        delegatedOnly
        returns (BSLib.Primitives memory)
    {
        return BSLib.get().p;
    }

    function balanceOfWant()
        public
        view
        virtual
        override
        delegatedOnly
        returns (uint256)
    {
        return BSLib.get().p.want.balanceOf(address(this));
    }

    function name()
        external
        view
        virtual
        override
        delegatedOnly
        returns (string memory)
    {
        revert InitializerLib.NotImplemented();
    }

    function estimatedTotalAssets()
        external
        view
        virtual
        override
        delegatedOnly
        returns (uint256)
    {
        revert InitializerLib.NotImplemented();
    }
}
