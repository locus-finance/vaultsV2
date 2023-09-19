// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISgBridge} from "../../../interfaces/ISgBridge.sol";
import {IStargateRouter} from "../../../integrations/stargate/IStargate.sol";

import "./interfaces/IBaseStrategyInitializerFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

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
        BSLib.Storage.Primitives storage p = BSLib.get().p;

        IBSLayerZeroFacet(address(this))._initialize(_lzEndpoint);
        p.strategist = _strategist;
        p.want = _want;
        p.vaultChainId = _vaultChainId;
        p.vault = _vault;
        p.slippage = _slippage;
        p.wantDecimals = IERC20Metadata(address(want)).decimals();
        p.signNonce = 0;
        p.currentChainId = _currentChainId;
        p.sgBridge = ISgBridge(_sgBridge);
        p.sgRouter = IStargateRouter(_sgRouter);

        want.approve(_sgBridge, type(uint256).max);
    }
}