// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSAdjustPositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../HSLib.sol";
import "./interfaces/IHSUtilsFacet.sol";
import "./interfaces/IHSStatsFacet.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

contract HSAdjustPositionFacet is BaseFacet, IBSAdjustPositionFacet {
    function adjustPosition(
        uint256 _debtOutstanding
    ) external override internalOnly {
        BSLib.Primitives memory p = BSLib.get().p;

        if (p.emergencyExit) {
            return;
        }
        IHSUtilsFacet(address(this)).claimAndSellRewards();
        uint256 unstakedBalance = IHSStatsFacet(address(this)).balanceOfWant();

        uint256 excessWant;
        if (unstakedBalance > _debtOutstanding) {
            excessWant = unstakedBalance - _debtOutstanding;
        }
        if (excessWant > 0) {
            uint256[] memory liqAmounts = new uint256[](2);
            liqAmounts[0] = excessWant;
            liqAmounts[1] = 0;
            uint256 minAmount = (IRouter(HSLib.HOP_ROUTER).calculateTokenAmount(
                address(this),
                liqAmounts,
                true
            ) * p.slippage) / BSLib.MAX_BPS;

            IRouter(HSLib.HOP_ROUTER).addLiquidity(
                liqAmounts,
                minAmount,
                block.timestamp
            );
            uint256 lpBalance = IERC20(HSLib.LP).balanceOf(address(this));
            IStakingRewards(HSLib.STAKING_REWARD).stake(lpBalance);
        }
    }
}
