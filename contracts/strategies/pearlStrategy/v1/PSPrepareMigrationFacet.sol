// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPearlGaugeV2} from "../../../integrations/pearl/IPearlGaugeV2.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSPrepareMigrationFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "./interfaces/IPSStatsFacet.sol";
import "../PSLib.sol";

contract PSPrepareMigrationFacet is BaseFacet, IBSPrepareMigrationFacet {
    using SafeERC20 for IERC20;

    function prepareMigration(
        address _newStrategy
    ) external override internalOnly {
        IPearlGaugeV2(PSLib.PEARL_GAUGE_V2).withdraw(
            IPSStatsFacet(address(this)).balanceOfLpStaked()
        );

        IERC20(PSLib.USDC_USDR_LP).safeTransfer(
            _newStrategy,
            IERC20(PSLib.USDC_USDR_LP).balanceOf(address(this))
        );
        IERC20(PSLib.USDR).safeTransfer(
            _newStrategy,
            IERC20(PSLib.USDR).balanceOf(address(this))
        );
        IERC20(PSLib.PEARL).safeTransfer(
            _newStrategy,
            IERC20(PSLib.PEARL).balanceOf(address(this))
        );
    }
}
