// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IPearlRouter} from "../../../integrations/pearl/IPearlRouter.sol";
import {IPearlGaugeV2} from "../../../integrations/pearl/IPearlGaugeV2.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "./interfaces/IPSStatsFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "./interfaces/IPSWithdrawAndExitFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../baseStrategy/v1/interfaces/IBSUtilsFacet.sol";
import "../PSLib.sol";

contract PSWithdrawAndExitFacet is BaseFacet, IPSWithdrawAndExitFacet {
    function withdrawSome(
        uint256 _amountNeeded
    ) external override internalOnly {
        if (_amountNeeded == 0) {
            return;
        }

        uint256 rewardsTotal = IPSUtilsFacet(address(this)).pearlToWant(
            IPSStatsFacet(address(this)).balanceOfPearlRewards()
        );
        if (rewardsTotal >= _amountNeeded) {
            IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).getReward();
            IPSUtilsFacet(address(this)).sellPearl(
                IERC20(PSLib.PEARL).balanceOf(address(this))
            );
        } else {
            uint256 lpTokensToWithdraw = Math.min(
                IPSUtilsFacet(address(this)).wantToUsdrLp(
                    _amountNeeded - rewardsTotal
                ),
                IPSStatsFacet(address(this)).balanceOfLpStaked()
            );
            exitPosition(lpTokensToWithdraw);
        }
    }

    function exitPosition(uint256 _stakedLpTokens) public override internalOnly {
        IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).getReward();
        IPSUtilsFacet(address(this)).sellPearl(
            IERC20(PSLib.PEARL).balanceOf(address(this))
        );

        if (_stakedLpTokens == 0) {
            return;
        }

        IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).withdraw(_stakedLpTokens);
        address wantAddress = address(BSLib.get().p.want);
        (uint256 amountA, uint256 amountB) = IPearlRouter(PSLib.PEARL_ROUTER)
            .quoteRemoveLiquidity(
                wantAddress,
                PSLib.USDR,
                true,
                _stakedLpTokens
            );
        IPearlRouter(PSLib.PEARL_ROUTER).removeLiquidity(
            wantAddress,
            PSLib.USDR,
            true,
            _stakedLpTokens,
            IBSUtilsFacet(address(this)).withSlippage(amountA),
            IBSUtilsFacet(address(this)).withSlippage(amountB),
            address(this),
            block.timestamp
        );

        IPSUtilsFacet(address(this)).sellUsdr(
            IERC20(PSLib.USDR).balanceOf(address(this))
        );
    }
}
