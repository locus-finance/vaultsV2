// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IHSUtilsFacet.sol";
import "../HSLib.sol";

contract HSUtilsFacet is BaseFacet, IHSUtilsFacet {
    function claimAndSellRewards() external override internalOnly {
        IStakingRewards(HSLib.STAKING_REWARD).getReward();
        sellHopForWant(IERC20(HSLib.HOP).balanceOf(address(this)));
    }

    function lpToWant(
        uint256 amountIn
    ) external override internalOnly view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        amountOut = IRouter(HSLib.HOP_ROUTER).calculateRemoveLiquidityOneToken(
            address(this),
            amountIn,
            0
        );
    }

    function hopToWant(
        uint256 amountIn
    ) external override internalOnly {
        IBSSwapHelperFacet(address(this)).quote(
            HSLib.HOP, address(BSLib.get().p.want), amountIn
        );
    }

    function sellHopForWant(uint256 amountToSell) public override internalOnly {
        if (amountToSell == 0) {
            return;
        }
        
        uint8 adjustedTo1InchSlippage = uint8(
            (BSLib.get().p.slippage * 100) / BSLib.MAX_BPS
        );
        IBSSwapHelperFacet(address(this)).swap(
            HSLib.HOP, HSLib.USDC, amountToSell, adjustedTo1InchSlippage
        );
    }

    function notifyCallback(
        address,
        address,
        uint256 amountOut,
        uint256
    ) external override internalOnly {
        HSLib.get().requestedQuoteHopToWant = amountOut;
    }
}