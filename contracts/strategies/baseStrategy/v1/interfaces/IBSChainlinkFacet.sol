// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../swaps/libraries/BSOneInchLib.sol";

interface IBSChainlinkFacet {
    function _initialize(
        uint256 _quoteJobFee, // Mainnet - 140 == 1.4 LINK
        uint256 _swapCalldataJobFee, // Mainnet - 1100 == 11 LINK
        address _aggregationRouter, // Mainnet - 0x1111111254EEB25477B68fb85Ed929f73A960582
        address chainlinkTokenAddress, // Mainnet - 0x514910771AF9Ca656af840dff83E8264EcF986CA
        address chainlinkOracleAddress, // Mainnet - 0x0168B5FcB54F662998B0620b9365Ae027192621f
        string memory _swapCalldataJobId, // Mainnet - e11192612ceb48108b4f2730a9ddbea3
        string memory _quoteJobId // Mainnet - 0eb8d4b227f7486580b6f66706ac5d47
    ) external;

    function requestChainlinkQuote(
        address src,
        address dst,
        uint256 amount,
        bytes4 callbackSignature
    ) external;

    function registerQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) external;

    function registerQuoteAndFulfillRequestOnOracleExpense(
        bytes32 requestId,
        uint256 toAmount
    ) external;

    function requestChainlinkSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage,
        bytes4 callbackSignature
    ) external;

    function registerSwapCalldata(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) external;

    function registerSwapCalldataAndFulfillOnOracleExpense(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) external;

    function setOracleAddress(
        address _oracleAddress
    ) external;

    function setJobInfo(
        BSOneInchLib.JobPurpose _purpose,
        BSOneInchLib.JobInfo memory _info
    ) external;

    function setFeeInHundredthsOfLink(
        BSOneInchLib.JobPurpose _purpose,
        uint256 _feeInHundredthsOfLink
    ) external;

    function getFeeInHundredthsOfLink(
        BSOneInchLib.JobPurpose _purpose
    ) external view returns (uint256);
}