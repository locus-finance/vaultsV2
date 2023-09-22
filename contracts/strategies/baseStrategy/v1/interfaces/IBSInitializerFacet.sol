// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint256 _slippage,
        uint256 _quoteJobFee, // Mainnet - 140 == 1.4 LINK
        uint256 _swapCalldataJobFee, // Mainnet - 1100 == 11 LINK
        address _aggregationRouter, // Mainnet - 0x1111111254EEB25477B68fb85Ed929f73A960582
        address chainlinkTokenAddress, // Mainnet - 0x514910771AF9Ca656af840dff83E8264EcF986CA
        address chainlinkOracleAddress, // Mainnet - 0x0168B5FcB54F662998B0620b9365Ae027192621f
        string memory _swapCalldataJobId, // Mainnet - e11192612ceb48108b4f2730a9ddbea3
        string memory _quoteJobId // Mainnet - 0eb8d4b227f7486580b6f66706ac5d47
    ) external;
}
