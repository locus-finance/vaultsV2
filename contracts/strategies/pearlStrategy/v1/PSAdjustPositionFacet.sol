// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IExchange} from "../../../integrations/usdr/IExchange.sol";
import {IPearlGaugeV2} from "../../../integrations/pearl/IPearlGaugeV2.sol";
import {IPearlRouter} from "../../../integrations/pearl/IPearlRouter.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSAdjustPositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../PSLib.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "./interfaces/IPSStatsFacet.sol";
import "../../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

contract PSAdjustPositionFacet is BaseFacet, IBSAdjustPositionFacet {
    function adjustPosition(
        uint256 _debtOutstanding
    ) external override internalOnly {
        IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).getReward();
        IPSUtilsFacet(address(this)).sellPearl(
            IERC20(PSLib.PEARL).balanceOf(address(this))
        );

        IERC20 want = BSLib.get().p.want;

        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > _debtOutstanding) {
            uint256 excessWant = wantBal - _debtOutstanding;
            uint256 halfWant = excessWant / 2;

            IBSSwapHelperFacet(address(this)).swap(
                address(want),
                PSLib.DAI,
                halfWant,
                PSLib.get().adjustedTo1InchSlippage
            );
        }

        uint256 daiBal = IERC20(PSLib.DAI).balanceOf(address(this));
        if (daiBal > 0) {
            IExchange(PSLib.USDR_EXCHANGE).swapFromUnderlying(daiBal, address(this));
        }

        uint256 usdrBal = IERC20(PSLib.USDR).balanceOf(address(this));
        wantBal = want.balanceOf(address(this));
        if (usdrBal > 0 && wantBal > 0) {
            (uint256 amountA, uint256 amountB, ) = IPearlRouter(
                PSLib.PEARL_ROUTER
            ).quoteAddLiquidity(
                    address(want),
                    PSLib.USDR,
                    true,
                    wantBal,
                    usdrBal
                );
            IPearlRouter(PSLib.PEARL_ROUTER).addLiquidity(
                address(want),
                PSLib.USDR,
                true,
                amountA,
                amountB,
                1,
                1,
                address(this),
                block.timestamp
            );
        }

        uint256 usdrLpBal = IERC20(PSLib.USDC_USDR_LP).balanceOf(address(this));
        if (usdrLpBal > 0) {
            IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).deposit(usdrLpBal);
        }
    }
}
