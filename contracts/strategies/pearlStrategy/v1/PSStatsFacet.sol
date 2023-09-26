// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IPearlGaugeV2} from "../../../integrations/pearl/IPearlGaugeV2.sol";

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

    function balanceOfPearlRewards() public view delegatedOnly override returns (uint256) {
        return IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).earned(address(this));
    }

    function balanceOfLpStaked() public view delegatedOnly override returns (uint256) {
        return IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).balanceOf(address(this));
    }

    function estimatedTotalAssets()
        public
        view
        override(BSStatsFacet, IBSStatsFacet)
        delegatedOnly
        returns (uint256)
    {
        return
            BSLib.get().p.want.balanceOf(address(this)) +
            IPSUtilsFacet(address(this)).pearlToWant(
                balanceOfPearlRewards() +
                    IERC20(PSLib.PEARL).balanceOf(address(this))
            ) +
            IPSUtilsFacet(address(this)).usdrLpToWant(balanceOfLpStaked());
    }
}
