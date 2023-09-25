// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSLiquidatePositionFacet.sol";
import "../../baseStrategy/v1/interfaces/forSpecificStrategies/IBSPrepareMigrationFacet.sol";
import "../../baseStrategy/BSLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";

contract PSPrepareMigrationFacet is BaseFacet, IBSPrepareMigrationFacet {
    using SafeERC20 for IERC20;

    function prepareMigration(address _newStrategy) external internalOnly override {
        uint256 assets = IBSLiquidatePositionFacet(address(this)).liquidateAllPositions();
        BSLib.get().p.want.safeTransfer(_newStrategy, assets);
    }
}