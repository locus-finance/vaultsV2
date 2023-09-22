// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../baseStrategy/v1/interfaces/IBSInitializerFacet.sol";
import "./interfaces/IHSInitializerFacet.sol";
import "../../diamondBase/libraries/InitializerLib.sol";
import "../../diamondBase/facets/BaseFacet.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HSInitializerFacet is BaseFacet, IHSInitializerFacet {
    function initialize(
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
    ) external override {
        InitializerLib.initialize();
        IBSInitializerFacet(address(this)).__BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            _currentChainId,
            _sgBridge,
            _sgRouter,
            _slippage,
            _quoteJobFee,
            _swapCalldataJobFee, 
            _aggregationRouter, 
            _chainlinkTokenAddress, 
            _chainlinkOracleAddress, 
            _swapCalldataJobId, 
            _quoteJobId
        );
        // swapHelper = IOraclizedSwapHelper(_swapHelper);
        // IERC20(HOP).approve(_swapHelper, type(uint256).max);
        // IERC20(LP).approve(STAKING_REWARD, type(uint256).max);
        // IERC20(LP).approve(HOP_ROUTER, type(uint256).max);
        // IERC20(HOP).approve(UNISWAP_V3_ROUTER, type(uint256).max);
        // want.approve(HOP_ROUTER, type(uint256).max);
    }
}