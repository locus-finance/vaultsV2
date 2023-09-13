// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./ISwapHelper.sol";

interface IOraclizedSwapHelper is ISwapHelper {
    enum JobPurpose {
        QUOTE, SWAP_CALLDATA
    }

    enum StrategistInterference {
        QUOTE_REQUEST_PERFORMED_MANUALLY,
        SWAP_CALLDATA_REQUEST_PEROFRMED_MANUALLY
    }

    struct JobInfo {
        bytes32 jobId;
        uint256 jobFeeInJuels;
    }

    struct SwapInfo {
        address srcToken;
        address dstToken;
        uint256 inAmount;
    }

    struct QuoteInfo {
        SwapInfo swapInfo;
        uint256 outAmount;
    }

    error TransferError();
    error SlippageIsTooBig();
    error NotEnoughNativeTokensSent();
    error CannotAddSubscriber();
    error CannotRemoveSubscriber();
    error SwapOperationIsNotReady();
    error QuoteOperationIsNotReady();
    error OnlySelfAuthorized();

    event Quote(SwapInfo indexed _quoteBuffer);
    event Swap(SwapInfo indexed _swapBuffer);
    event EmergencyQuote(SwapInfo indexed _quoteBuffer, bytes indexed errorData);
    event EmergencySwap(SwapInfo indexed _swapBuffer, bytes indexed errorData);

    event QuoteSent(QuoteInfo indexed _quoteBuffer);
    event QuoteRegistered(uint256 indexed toAmount);

    event SwapPerformed(SwapInfo indexed _swapBuffer);
    event SwapRegistered(bytes indexed swapCalldata);

    event StrategistInterferred(StrategistInterference indexed interference);

    function fulfillSwap() external;

    function fulfillQuote() external;

    function requestQuoteAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount
    ) external;

    function requestSwapAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable;

    function quoteBuffer() external view returns(
        SwapInfo memory,
        uint256 outAmount
    );

    function swapBuffer() external view returns(
        address srcToken,
        address dstToken,
        uint256 inAmount
    );
}