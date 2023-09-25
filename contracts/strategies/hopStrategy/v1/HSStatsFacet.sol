// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";

import "./interfaces/IHSStatsFacet.sol";
import "../../baseStrategy/v1/BSStatsFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IHSUtilsFacet.sol";
import "../HSLib.sol";

contract HSStatsFacet is BSStatsFacet, IHSStatsFacet {
    function getHopStrategyPrimitives()
        external
        pure
        override
        returns (HSLib.Storage memory)
    {
        return HSLib.get();
    }

    function name()
        external
        pure
        override(BSStatsFacet, IBSStatsFacet)
        returns (string memory)
    {
        return "HopStrategy";
    }

    /// @dev MUST BE CALLED BEFORE estimatedTotalAssets() AND withdrawSome()
    function updateHopToWantBuffer() external override delegatedOnly {
        IHSUtilsFacet(address(this)).hopToWant(rewardsEarned());
    }

    function estimatedTotalAssets()
        public
        view
        override(BSStatsFacet, IBSStatsFacet)
        delegatedOnly
        returns (uint256)
    {
        return
            IHSUtilsFacet(address(this)).lpToWant(balanceOfStaked()) +
            balanceOfWant() +
            HSLib.get().requestedQuoteHopToWant; // WARNING: IF NOT UPDATED COULD BE DEPRECATED OR 0
    }

    function balanceOfStaked()
        public
        view
        override
        delegatedOnly
        returns (uint256 amount)
    {
        amount = IStakingRewards(HSLib.STAKING_REWARD).balanceOf(address(this));
    }

    function rewardsEarned()
        public
        view
        override
        delegatedOnly
        returns (uint256 amount)
    {
        amount = IStakingRewards(HSLib.STAKING_REWARD).earned(address(this));
    }
}
