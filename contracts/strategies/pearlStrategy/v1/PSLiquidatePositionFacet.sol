// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../PSLib.sol";
import "./interfaces/IPSWithdrawAndExitFacet.sol";
import "./interfaces/IPSStatsFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";

contract PSLiquidatePositionFacet is BaseFacet, IBSLiquidatePositionFacet {
    function liquidatePosition(
        uint256 _amountNeeded
    )
        external
        override
        internalOnly
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        IERC20 want = BSLib.get().p.want;

        uint256 _wantBal = want.balanceOf(address(this));
        if (_wantBal >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        IPSWithdrawAndExitFacet(address(this)).withdrawSome(
            _amountNeeded - _wantBal
        );
        _wantBal = want.balanceOf(address(this));

        if (_amountNeeded > _wantBal) {
            _liquidatedAmount = _wantBal;
            _loss = _amountNeeded - _wantBal;
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function liquidateAllPositions()
        external
        override
        internalOnly
        returns (uint256 _amountFreed)
    {
        IPSWithdrawAndExitFacet(address(this)).exitPosition(
            IPSStatsFacet(address(this)).balanceOfLpStaked()
        );
        _amountFreed = BSLib.get().p.want.balanceOf(address(this));
    }
}
