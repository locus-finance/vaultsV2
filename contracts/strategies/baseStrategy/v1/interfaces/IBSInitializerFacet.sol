// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contract/token/ERC20/IERC20.sol";

interface IBSInitializerFacet {
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
    ) external;
}