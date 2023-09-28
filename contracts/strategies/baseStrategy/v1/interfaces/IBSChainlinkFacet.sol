// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../swaps/libraries/BSOneInchLib.sol";

/// @title An interface that contains a functionality that is triggered once a strategy wants
/// to perform either swap or quote operation using oraclized 1inch-integrated facets.
/// @author Locus Team
/// @notice The interface has to be implemented in any strategy that is to utilize base strategy facets.
interface IBSChainlinkFacet {

    /// @notice Initializes an internal state of the Chainlink Node connection. Could be only called inside
    /// of an implementing facet.
    /// @param _quoteJobFee A fee in hundreds of LINK tokens to be charged on every quote operation.
    /// @param _swapCalldataJobFee A fee in hundreds of LINK tokens to be charged on every swap operation.
    /// @param _aggregationRouter An address of AggregationRouter contract of 1inch Aggregation Protocol.
    /// @param chainlinkTokenAddress An address of LINK.
    /// @param chainlinkOracleAddress An address of the Chainlink Oracle.
    /// @param _swapCalldataJobId An ID of a swap generation job on Chainlink Node.
    /// @param _quoteJobId An ID of a quote generation job on Chainlink Node.
    function _initialize(
        uint256 _quoteJobFee, // Mainnet - 140 == 1.4 LINK
        uint256 _swapCalldataJobFee, // Mainnet - 1100 == 11 LINK
        address _aggregationRouter, // Mainnet - 0x1111111254EEB25477B68fb85Ed929f73A960582
        address chainlinkTokenAddress, // Mainnet - 0x514910771AF9Ca656af840dff83E8264EcF986CA
        address chainlinkOracleAddress, // Mainnet - 0x0168B5FcB54F662998B0620b9365Ae027192621f
        string memory _swapCalldataJobId, // Mainnet - e11192612ceb48108b4f2730a9ddbea3
        string memory _quoteJobId // Mainnet - 0eb8d4b227f7486580b6f66706ac5d47
    ) external;

    /// @notice Posts a request to the Chainlink Oracle node to call a quote on 1inch Aggregation Protocol API.
    /// Could only be called inside of an implementing facet.
    /// @param src An address of the token to be quoted.
    /// @param dst An address of the token to be received.
    /// @param amount An amount of token `src`.
    /// @param callbackSignature A signature of callback to be called by Chainlink Oracle to pass the quote
    /// operation result.
    function requestChainlinkQuote(
        address src,
        address dst,
        uint256 amount,
        bytes4 callbackSignature
    ) external;

    /// @notice Registers an amount out of the quote operation. Could only be called by Chainlink Oracle contract.
    /// @param requestId An ID of the Chainlink Oracle request for quote operation. 
    /// @param toAmount An amount of tokens out in quote operation provided by the oracle.
    function registerQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) external;

    /// @notice Registers an amount out of the quote operation and immideately updates the state of the
    /// facet. Could only be called by Chainlink Oracle contract.
    /// @param requestId An ID of the Chainlink Oracle request for quote operation.
    /// @param toAmount An amount of tokens out in quote operation provided by the oracle.
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