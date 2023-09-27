// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library BSOneInchLib {
    bytes32 constant BASE_STRATEGY_ONE_INCH_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.base_strategy.one_inch");

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

    error LinkTransferError();
    error SlippageIsTooBig();
    error NotEnoughNativeTokensSent();
    error SwapOperationIsNotReady();
    error QuoteOperationIsNotReady();

    event Quote(SwapInfo indexed _quoteBuffer);
    event Swap(SwapInfo indexed _swapBuffer);
    event EmergencyQuote(SwapInfo indexed _quoteBuffer, bytes indexed errorData);
    event EmergencySwap(SwapInfo indexed _swapBuffer, bytes indexed errorData);

    event QuoteSent(QuoteInfo indexed _quoteBuffer);
    event QuoteRegistered(uint256 indexed toAmount);

    event SwapPerformed(SwapInfo indexed _swapBuffer);
    event SwapRegistered(bytes indexed swapCalldata);

    event StrategistInterferred(StrategistInterference indexed interference);

    event Notified(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );

    address public constant ONE_INCH_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct ReferenceTypes {
        mapping(uint256 => JobInfo) jobInfos;
    }

    struct Primitives {
        address aggregationRouter;
        address oracleAddress;
        QuoteInfo quoteBuffer;
        SwapInfo swapBuffer;
        bool isReadyToFulfillSwap;
        bool isReadyToFulfillQuote;
        bytes lastSwapCalldata;
    }

    struct Storage {
        ReferenceTypes rt; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE 
        Primitives p; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = BASE_STRATEGY_ONE_INCH_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}