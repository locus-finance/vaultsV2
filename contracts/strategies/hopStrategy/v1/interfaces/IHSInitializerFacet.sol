// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHSInitializerFacet {
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
    ) external;
}