// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "./interfaces/IHSStatsFacet.sol";
import "./interfaces/IHSUtilsFacet.sol";
import "./interfaces/IHSWithdrawAndExitFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../HSLib.sol";

contract HSWithdrawAndExitFacet is BaseFacet, IHSWithdrawAndExitFacet {
    function withdrawSome(uint256 _amountNeeded) external override internalOnly {
        if (_amountNeeded == 0) {
            return;
        }
        uint256 hopRewardsInWantToken = HSLib.get().requestedQuoteHopToWant;
        if (hopRewardsInWantToken >= _amountNeeded) {
            IHSUtilsFacet(address(this)).claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                IHSStatsFacet(address(this)).balanceOfStaked(),
                _amountNeeded - hopRewardsInWantToken
            );
            exitPosition(_usdcToUnstake);
        }
    }

    function exitPosition(uint256 _stakedAmount) public internalOnly override {
        IHSUtilsFacet(address(this)).claimAndSellRewards();

        uint256[] memory amountsToWithdraw = new uint256[](2);
        amountsToWithdraw[0] = _stakedAmount;
        amountsToWithdraw[1] = 0;

        uint256 amountLpToWithdraw = IRouter(HSLib.HOP_ROUTER).calculateTokenAmount(
            address(this),
            amountsToWithdraw,
            false
        );

        uint256 balanceOfWant = IHSStatsFacet(address(this)).balanceOfWant();
        if (amountLpToWithdraw > balanceOfWant) {
            amountLpToWithdraw = balanceOfWant;
        }

        IStakingRewards(HSLib.STAKING_REWARD).withdraw(amountLpToWithdraw);
        uint256 minAmount = (_stakedAmount * BSLib.get().p.slippage) / BSLib.MAX_BPS;

        IRouter(HSLib.HOP_ROUTER).removeLiquidityOneToken(
            amountLpToWithdraw,
            0,
            minAmount,
            block.timestamp
        );
    }
}