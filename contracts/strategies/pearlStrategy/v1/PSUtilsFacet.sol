// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Utils} from "../../../utils/Utils.sol";
import {IPearlRouter, IPearlPair} from "../../../integrations/pearl/IPearlRouter.sol";

import "../../../integrations/hop/IStakingRewards.sol";
import "../../../integrations/hop/IRouter.sol";

import "../../baseStrategy/v1/interfaces/IBSSwapHelperFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IPSUtilsFacet.sol";
import "../PSLib.sol";

contract PSUtilsFacet is BaseFacet, IPSUtilsFacet {
    function pearlToWant(
        uint256 _pearlAmount
    ) external view override internalOnly returns (uint256) {
        uint256 usdrAmount = IPearlPair(PSLib.PEARL_USDR_LP).current(
            PSLib.PEARL,
            _pearlAmount
        );
        return usdrToWant(usdrAmount);
    }

    function usdrToWant(
        uint256 _usdrAmount
    ) public view override internalOnly returns (uint256) {
        return
            Utils.scaleDecimals(
                _usdrAmount,
                IERC20Metadata(PSLib.USDR).decimals(),
                BSLib.get().p.wantDecimals
            );
    }

    function daiToWant(
        uint256 _daiAmount
    ) external view override internalOnly returns (uint256) {
        return
            Utils.scaleDecimals(
                _daiAmount,
                IERC20Metadata(PSLib.DAI).decimals(),
                BSLib.get().p.wantDecimals
            );
    }

    function usdrLpToWant(
        uint256 _usdrLpAmount
    ) public view override internalOnly returns (uint256) {
        (uint256 amountA, uint256 amountB) = IPearlRouter(PSLib.PEARL_ROUTER)
            .quoteRemoveLiquidity(
                address(BSLib.get().p.want),
                PSLib.USDR,
                true,
                _usdrLpAmount
            );
        return amountA + usdrToWant(amountB);
    }

    function wantToUsdrLp(
        uint256 _wantAmount
    ) external view override internalOnly returns (uint256) {
        uint256 oneLp = usdrLpToWant(
            10 ** IERC20Metadata(PSLib.USDC_USDR_LP).decimals()
        );
        uint8 wantDecimals = BSLib.get().p.wantDecimals;
        uint8 usdcUsdrLpDecimals = IERC20Metadata(PSLib.USDC_USDR_LP)
            .decimals();
        uint256 scaledWantAmount = Utils.scaleDecimals(
            _wantAmount,
            wantDecimals,
            usdcUsdrLpDecimals
        );
        uint256 scaledLp = Utils.scaleDecimals(
            oneLp,
            wantDecimals,
            usdcUsdrLpDecimals
        );

        return (scaledWantAmount * (10 ** usdcUsdrLpDecimals)) / scaledLp;
    }

    function sellUsdr(uint256 _usdrAmount) external override internalOnly {
        if (_usdrAmount == 0) {
            return;
        }
        IBSSwapHelperFacet(address(this)).swap(
            PSLib.USDR,
            address(BSLib.get().p.want),
            _usdrAmount,
            PSLib.get().adjustedTo1InchSlippage
        );
    }

    function sellPearl(uint256 _pearlAmount) external override internalOnly {
        if (_pearlAmount == 0) {
            return;
        }
        IBSSwapHelperFacet(address(this)).swap(
            PSLib.PEARL,
            address(BSLib.get().p.want),
            _pearlAmount,
            PSLib.get().adjustedTo1InchSlippage
        );
    }

    function notifyCallback(
        address,
        address,
        uint256,
        uint256
    ) external override internalOnly {}
}
