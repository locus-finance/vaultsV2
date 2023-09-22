// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISgBridge} from "../../../interfaces/ISgBridge.sol";
import {IStargateRouter} from "../../../integrations/stargate/IStargate.sol";

import "./interfaces/IBSLayerZeroFacet.sol";
import "./interfaces/IBSInitializerFacet.sol";
import "./interfaces/IBSChainlinkFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../diamondBase/libraries/RolesManagementLib.sol";
import "../BSLib.sol";

contract BSInitializerFacet is BaseFacet, IBSInitializerFacet {
    function __BaseStrategy_init(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _sgRouter,
        uint256 _slippage,
        uint256 _quoteJobFee,
        uint256 _swapCalldataJobFee, 
        address _aggregationRouter, 
        address _chainlinkTokenAddress, 
        address _chainlinkOracleAddress, 
        string memory _swapCalldataJobId, 
        string memory _quoteJobId
    ) external override internalOnly {
        BSLib.Primitives storage p = BSLib.get().p;

        IBSLayerZeroFacet(address(this))._initialize(_lzEndpoint);
        IBSChainlinkFacet(address(this))._initialize(
            _quoteJobFee,
            _swapCalldataJobFee,
            _aggregationRouter,
            _chainlinkTokenAddress,
            _chainlinkOracleAddress,
            _swapCalldataJobId,
            _quoteJobId
        );

        p.strategist = _strategist;
        RolesManagementLib.grantRole(_strategist, RolesManagementLib.STRATEGIST_ROLE);
        RolesManagementLib.grantRole(msg.sender, RolesManagementLib.OWNER_ROLE);
        
        p.want = _want;
        p.vaultChainId = _vaultChainId;
        p.vault = _vault;
        p.slippage = _slippage;
        p.wantDecimals = IERC20Metadata(address(_want)).decimals();
        p.signNonce = 0;
        p.currentChainId = _currentChainId;
        p.sgBridge = ISgBridge(_sgBridge);
        p.sgRouter = IStargateRouter(_sgRouter);
        
        p.want.approve(_sgBridge, type(uint256).max);
    }
}