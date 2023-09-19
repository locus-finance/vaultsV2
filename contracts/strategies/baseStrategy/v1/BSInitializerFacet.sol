// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISgBridge} from "../../../interfaces/ISgBridge.sol";
import {IStargateRouter} from "../../../integrations/stargate/IStargate.sol";

import "./interfaces/IBaseStrategyInitializerFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";

contract BSInitializerFacet is BaseFacet, IBaseStrategyInitializerFacet {
    function __BaseStrategy_init(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _sgRouter,
        uint256 _slippage
    ) external override internalOnly {
        IBSLayerZeroFacet(address(this))._initialize(_lzEndpoint);
        strategist = _strategist;
        want = _want;
        vaultChainId = _vaultChainId;
        vault = _vault;
        slippage = _slippage;
        wantDecimals = IERC20Metadata(address(want)).decimals();
        _signNonce = 0;
        currentChainId = _currentChainId;
        sgBridge = ISgBridge(_sgBridge);
        sgRouter = IStargateRouter(_sgRouter);

        want.approve(_sgBridge, type(uint256).max);
    }
}