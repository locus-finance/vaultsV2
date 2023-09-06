// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../interfaces/ISwapHelper.sol";
import "../interfaces/ISwapHelperSubscriber.sol";

contract SwapHelper is AccessControl, ChainlinkClient, ISwapHelper {
    using Address for address;
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;
    using EnumerableSet for EnumerableSet.AddressSet;

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

    event QuoteSent(QuoteInfo indexed _quoteBuffer);
    event QuoteRegistered(uint256 indexed toAmount);

    event SwapPerformed(SwapInfo indexed _swapBuffer);
    event SwapRegistered(bytes indexed swapCalldata);

    event StrategistInterferred(StrategistInterference indexed interference);

    address public constant ONE_INCH_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 public constant SWAP_AUTHORIZED_ROLE =
        keccak256("SWAP_AUTHORIZED_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 public constant QUOTE_AUTHORIZED_ROLE = keccak256("QUOTE_AUTHORIZED_ROLE");

    address public immutable aggregationRouter;

    address public oracleAddress;

    QuoteInfo public quoteBuffer;
    SwapInfo public swapBuffer;

    bool public isReadyToFulfillSwap;
    bool public isReadyToFulfillQuote;

    mapping(uint256 => JobInfo) public jobInfos;
    bytes internal _lastSwapCalldata;
    EnumerableSet.AddressSet internal _subscribers;

    constructor(
        uint256 _quoteJobFee, // Mainnet - 140 == 1.4 LINK
        uint256 _swapCalldataJobFee, // Mainnet - 1100 == 11 LINK
        address _strategist,
        address _aggregationRouter, // Mainnet - 0x1111111254EEB25477B68fb85Ed929f73A960582
        address chainlinkTokenAddress, // Mainnet - 0x514910771AF9Ca656af840dff83E8264EcF986CA
        address chainlinkOracleAddress, // Mainnet - 0x0168B5FcB54F662998B0620b9365Ae027192621f
        string memory _swapCalldataJobId, // Mainnet - e11192612ceb48108b4f2730a9ddbea3
        string memory _quoteJobId, // Mainnet - 0eb8d4b227f7486580b6f66706ac5d47
        address[] memory authorizedToSwap
    ) {
        _grantRole(STRATEGIST_ROLE, _strategist);
        _grantRole(QUOTE_AUTHORIZED_ROLE, _strategist);
        _grantRole(SWAP_AUTHORIZED_ROLE, _strategist);

        setChainlinkToken(chainlinkTokenAddress);
        setOracleAddress(chainlinkOracleAddress);

        setJobInfo(JobPurpose.QUOTE, JobInfo({
            jobId: bytes32(bytes(_quoteJobId)),
            jobFeeInJuels: 0
        }));
        setFeeInHundredthsOfLink(JobPurpose.QUOTE, _quoteJobFee);

        setJobInfo(JobPurpose.SWAP_CALLDATA, JobInfo({
            jobId: bytes32(bytes(_swapCalldataJobId)),
            jobFeeInJuels: 0
        }));
        setFeeInHundredthsOfLink(JobPurpose.SWAP_CALLDATA, _swapCalldataJobFee);

        aggregationRouter = _aggregationRouter;
        for (uint8 i = 0; i < authorizedToSwap.length; i++) {
            _grantRole(SWAP_AUTHORIZED_ROLE, authorizedToSwap[uint256(i)]);
        }
    }

    // Update oracle address
    function setOracleAddress(
        address _oracleAddress
    ) public onlyRole(STRATEGIST_ROLE) {
        oracleAddress = _oracleAddress;
        setChainlinkOracle(_oracleAddress);
    }

    function getOracleAddress()
        public
        view
        onlyRole(STRATEGIST_ROLE)
        returns (address)
    {
        return oracleAddress;
    }

    function setJobInfo(JobPurpose _purpose, JobInfo memory _info) public onlyRole(STRATEGIST_ROLE) {
        jobInfos[uint256(_purpose)] = _info;
    }

    function setFeeInHundredthsOfLink(
        JobPurpose _purpose,
        uint256 _feeInHundredthsOfLink
    ) public onlyRole(STRATEGIST_ROLE) {
        jobInfos[uint256(_purpose)].jobFeeInJuels = (_feeInHundredthsOfLink * LINK_DIVISIBILITY) / 100;
    }

    function getFeeInHundredthsOfLink(
        JobPurpose _purpose
    )
        public
        view
        onlyRole(STRATEGIST_ROLE)
        returns (uint256)
    {
        return (jobInfos[uint256(_purpose)].jobFeeInJuels * 100) / LINK_DIVISIBILITY;
    }

    function addSubscriber(
        address subscriber
    ) external onlyRole(STRATEGIST_ROLE) {
        if (!_subscribers.add(subscriber)) {
            revert CannotAddSubscriber();
        }
    }

    function removeSubscriber(
        address subscriber
    ) external onlyRole(STRATEGIST_ROLE) {
        if (!_subscribers.remove(subscriber)) {
            revert CannotRemoveSubscriber();
        }
    }

    function subscriberAt(
        uint256 subscriberIdx
    ) external view returns (address) {
        return _subscribers.at(subscriberIdx);
    }

    function subscribersLength() external view returns (uint256) {
        return _subscribers.length();
    }

    function _requestQuote(
        address src,
        address dst,
        uint256 amount,
        bytes4 callbackSignature
    ) internal {
        Chainlink.Request memory req = buildOperatorRequest(
            jobInfos[uint256(JobPurpose.QUOTE)].jobId,
            callbackSignature
        );
        req.add("method", "GET");
        req.add(
            "url",
            string(
                abi.encodePacked(
                    "https://api.1inch.dev/swap/v5.2/1/quote?src=",
                    Strings.toHexString(src),
                    "&dst=",
                    Strings.toHexString(dst),
                    "&amount=",
                    Strings.toString(amount)
                )
            )
        );
        req.add("contact", "locus-finance");
        quoteBuffer.swapInfo.srcToken = src;
        quoteBuffer.swapInfo.dstToken = dst;
        quoteBuffer.swapInfo.inAmount = amount;
        // Send the request to the Chainlink oracle
        sendOperatorRequest(req, jobInfos[uint256(JobPurpose.QUOTE)].jobFeeInJuels);
    }

    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override onlyRole(QUOTE_AUTHORIZED_ROLE) {
        isReadyToFulfillQuote = false; // double check the flag
        _requestQuote(src, dst, amount, this.registerQuoteRequest.selector);
    }

    function requestQuoteAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount
    ) external override onlyRole(QUOTE_AUTHORIZED_ROLE) {
        _requestQuote(
            src, 
            dst, 
            amount, 
            this.registerQuoteAndFulfillRequestOnOracleExpense.selector
        );
    }

    function _fulfillQuoteRequest() internal {
        uint256 length = _subscribers.length();
        for (uint256 i = 0; i < length; i++) {
            ISwapHelperSubscriber(_subscribers.at(i)).notifyCallback(
                quoteBuffer.swapInfo.srcToken,
                quoteBuffer.swapInfo.dstToken,
                quoteBuffer.outAmount,
                quoteBuffer.swapInfo.inAmount
            );
        }
        emit QuoteSent(quoteBuffer);
    }

    function registerQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) public recordChainlinkFulfillment(requestId) {
        quoteBuffer.outAmount = toAmount;
        isReadyToFulfillQuote = true;
        emit QuoteRegistered(toAmount);
    }

    function registerQuoteAndFulfillRequestOnOracleExpense(
        bytes32 requestId,
        uint256 toAmount
    ) public recordChainlinkFulfillment(requestId) {
        quoteBuffer.outAmount = toAmount;
        emit QuoteRegistered(toAmount);
        _fulfillQuoteRequest();
    }

    function fulfillQuote() external override onlyRole(QUOTE_AUTHORIZED_ROLE) {
        if (!isReadyToFulfillQuote) {
            revert QuoteOperationIsNotReady();
        }
        _fulfillQuoteRequest();
        isReadyToFulfillQuote = false;
    }

    function strategistFulfillQuote(uint256 toAmount) external onlyRole(STRATEGIST_ROLE) {
        isReadyToFulfillQuote = false; // reset the flag
        quoteBuffer.outAmount = toAmount;
        emit QuoteRegistered(toAmount);
        _fulfillQuoteRequest();
        emit StrategistInterferred(StrategistInterference.QUOTE_REQUEST_PERFORMED_MANUALLY);
    }

    function _setMaxAllowancesIfNeededAndCheckPayment(address src, uint256 amount, address sender) internal {
        IERC20 srcErc20 = IERC20(src);
        if (src == ONE_INCH_ETH_ADDRESS) {
            if (msg.value != amount) {
                revert NotEnoughNativeTokensSent();
            }
        } else {
            srcErc20.safeTransferFrom(sender, address(this), amount);
            // make sure if allowances are at max so we would make cheaper future txs
            if (srcErc20.allowance(address(this), aggregationRouter) < amount) {
                srcErc20.approve(aggregationRouter, type(uint256).max);
            }
        }
    }

    function _requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage,
        bytes4 callbackSignature
    ) internal {
        if (slippage > 50) {
            revert SlippageIsTooBig(); // A constraint dictated by 1inch Aggregation Protocol
        }

        address sender = _msgSender();
        _setMaxAllowancesIfNeededAndCheckPayment(src, amount, sender);

        Chainlink.Request memory req = buildOperatorRequest(
            jobInfos[uint256(JobPurpose.SWAP_CALLDATA)].jobId,
            callbackSignature
        );
        req.add("method", "GET");
        req.add(
            "url",
            string(
                abi.encodePacked(
                    "https://api.1inch.dev/swap/v5.2/1/swap?src=",
                    Strings.toHexString(src),
                    "&dst=",
                    Strings.toHexString(dst),
                    "&amount=",
                    Strings.toString(amount),
                    "&from=",
                    Strings.toHexString(address(this)),
                    "&slippage=",
                    Strings.toString(slippage),
                    "&receiver=",
                    Strings.toHexString(sender),
                    "&disableEstimate=true"
                )
            )
        );
        req.add("contact", "locus-finance");
        swapBuffer = SwapInfo({
            srcToken: src,
            dstToken: dst,
            inAmount: amount
        });
        sendOperatorRequest(req, jobInfos[uint256(JobPurpose.SWAP_CALLDATA)].jobFeeInJuels);
    }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override onlyRole(SWAP_AUTHORIZED_ROLE) {
        isReadyToFulfillSwap = false; // double check if the flag is down
        _requestSwap(src, dst, amount, slippage, this.registerSwapCalldata.selector);
    }

    function requestSwapAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override onlyRole(SWAP_AUTHORIZED_ROLE) {
        isReadyToFulfillSwap = false; // double check if the flag is down
        _requestSwap(src, dst, amount, slippage, this.registerSwapCalldata.selector);
    }

    function registerSwapCalldata(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) public recordChainlinkFulfillment(requestId) {
        _lastSwapCalldata = swapCalldata;
        isReadyToFulfillSwap = true;
        emit SwapRegistered(swapCalldata);
    }

    function registerSwapCalldataAndFulfillOnOracleExpense(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) public recordChainlinkFulfillment(requestId) {
        _lastSwapCalldata = swapCalldata;
        emit SwapRegistered(swapCalldata);
        _setMaxAllowancesIfNeededAndCheckPayment(swapBuffer.srcToken, swapBuffer.inAmount, _msgSender());
        _fulfillSwap();
    }

    function _fulfillSwap() internal {
        if (swapBuffer.srcToken == ONE_INCH_ETH_ADDRESS) {
            aggregationRouter.functionCallWithValue(
                _lastSwapCalldata,
                swapBuffer.inAmount
            );
        } else {
            aggregationRouter.functionCall(_lastSwapCalldata);
        }
        emit SwapPerformed(swapBuffer);
    }

    function fulfillSwap() external override onlyRole(SWAP_AUTHORIZED_ROLE) {
        if (!isReadyToFulfillSwap) {
            revert SwapOperationIsNotReady();
        }
        _fulfillSwap();
        isReadyToFulfillSwap = false;
    }

    function strategistFulfillSwap(bytes memory _swapCalldata) 
        external 
        payable 
        onlyRole(STRATEGIST_ROLE)
    {
        isReadyToFulfillSwap = false;
        _lastSwapCalldata = _swapCalldata;
        _setMaxAllowancesIfNeededAndCheckPayment(swapBuffer.srcToken, swapBuffer.inAmount, _msgSender());
        _fulfillSwap();
        emit StrategistInterferred(StrategistInterference.SWAP_CALLDATA_REQUEST_PEROFRMED_MANUALLY);
    }

    function withdrawLink() public onlyRole(STRATEGIST_ROLE) {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        if (!link.transfer(_msgSender(), link.balanceOf(address(this)))) {
            revert TransferError();
        }
    }

    receive() external payable {}
}
