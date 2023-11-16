// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../HSLib.sol";
import "./interfaces/IHSWithdrawAndExitFacet.sol";
import "./interfaces/IHSStatsFacet.sol";
import "./interfaces/IHSUtilsFacet.sol";

contract HSLiquidatePositionFacet is BaseFacet, IBSLiquidatePositionFacet {
    function liquidatePosition(
        uint256 _amountNeeded
    )
        external
        override
        internalOnly
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        BSLib.Primitives memory p = BSLib.get().p;

        uint256 _wantBal = p.want.balanceOf(address(this));
        if (_wantBal >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        IHSWithdrawAndExitFacet(address(this)).withdrawSome(_amountNeeded - _wantBal);
        _wantBal = p.want.balanceOf(address(this));

        if (_amountNeeded > _wantBal) {
            _liquidatedAmount = _wantBal;
            _loss = _amountNeeded - _wantBal;
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function liquidateAllPositions()
        external
        internalOnly
        override
        returns (uint256 _amountFreed)
    {
        IHSUtilsFacet(address(this)).claimAndSellRewards();

        uint256 stakingAmount = IHSStatsFacet(address(this)).balanceOfWant();
        IStakingRewards(HSLib.STAKING_REWARD).withdraw(stakingAmount);
        IRouter(HSLib.HOP_ROUTER).removeLiquidityOneToken(
            stakingAmount,
            0,
            0,
            block.timestamp
        );
        _amountFreed = BSLib.get().p.want.balanceOf(address(this));
    }
}
