// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "../../../diamondBase/libraries/RolesManagementLib.sol";
import "../../../diamondBase/facets/BaseFacet.sol";
import "./libraries/BSOneInchLib.sol";
import "../../BSLib.sol";
import "../interfaces/IBSChainlinkFacet.sol";
import "../interfaces/IBSOneInchQuoteFacet.sol";
import "../interfaces/IBSOneInchSwapFacet.sol";

contract BSChainlinkFacet is BaseFacet, ChainlinkClient, IBSChainlinkFacet {
    using Chainlink for Chainlink.Request;

    function _initialize(
        uint256 _quoteJobFee, 
        uint256 _swapCalldataJobFee, 
        address _aggregationRouter, 
        address chainlinkTokenAddress, 
        address chainlinkOracleAddress, 
        string memory _swapCalldataJobId,
        string memory _quoteJobId
    ) external override internalOnly {
        setChainlinkToken(chainlinkTokenAddress);
        setOracleAddress(chainlinkOracleAddress);

        setJobInfo(
            BSOneInchLib.JobPurpose.QUOTE,
            BSOneInchLib.JobInfo({
                jobId: bytes32(bytes(_quoteJobId)),
                jobFeeInJuels: 0
            })
        );
        setFeeInHundredthsOfLink(BSOneInchLib.JobPurpose.QUOTE, _quoteJobFee);

        setJobInfo(
            BSOneInchLib.JobPurpose.SWAP_CALLDATA,
            BSOneInchLib.JobInfo({
                jobId: bytes32(bytes(_swapCalldataJobId)),
                jobFeeInJuels: 0
            })
        );
        setFeeInHundredthsOfLink(
            BSOneInchLib.JobPurpose.SWAP_CALLDATA,
            _swapCalldataJobFee
        );

        BSOneInchLib.get().p.aggregationRouter = _aggregationRouter;
    }

    function setOracleAddress(
        address _oracleAddress
    ) public override delegatedOnly {
        BSOneInchLib.get().p.oracleAddress = _oracleAddress;
        setChainlinkOracle(_oracleAddress);
    }

    function setJobInfo(
        BSOneInchLib.JobPurpose _purpose,
        BSOneInchLib.JobInfo memory _info
    ) public override delegatedOnly {
        BSOneInchLib.get().rt.jobInfos[uint256(_purpose)] = _info;
    }

    function setFeeInHundredthsOfLink(
        BSOneInchLib.JobPurpose _purpose,
        uint256 _feeInHundredthsOfLink
    ) public override delegatedOnly {
        BSOneInchLib.get().rt.jobInfos[uint256(_purpose)].jobFeeInJuels =
            (_feeInHundredthsOfLink * LINK_DIVISIBILITY) /
            100;
    }

    function getFeeInHundredthsOfLink(
        BSOneInchLib.JobPurpose _purpose
    ) public view override delegatedOnly returns (uint256) {
        return
            (BSOneInchLib.get().rt.jobInfos[uint256(_purpose)].jobFeeInJuels *
                100) / LINK_DIVISIBILITY;
    }

    function registerQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) public override recordChainlinkFulfillment(requestId) {
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.quoteBuffer.outAmount = toAmount;
        p.isReadyToFulfillQuote = true;
        emit BSOneInchLib.QuoteRegistered(toAmount);
    }

    function registerQuoteAndFulfillRequestOnOracleExpense(
        bytes32 requestId,
        uint256 toAmount
    ) public override recordChainlinkFulfillment(requestId) {
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.quoteBuffer.outAmount = toAmount;
        emit BSOneInchLib.QuoteRegistered(toAmount);
        IBSOneInchQuoteFacet(address(this)).fulfillQuoteRequest();
    }

    /// @dev Naming convention is broken due to actual visibility made by the modifier `onlySelfAuthorized`.
    /// Made like that to be executable through the CALL opcode.
    function requestChainlinkQuote(
        address src,
        address dst,
        uint256 amount,
        bytes4 callbackSignature
    ) external override internalOnly {
        BSOneInchLib.ReferenceTypes storage rt = BSOneInchLib.get().rt;
        Chainlink.Request memory req = buildOperatorRequest(
            rt.jobInfos[uint256(BSOneInchLib.JobPurpose.QUOTE)].jobId,
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
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.quoteBuffer.swapInfo.srcToken = src;
        p.quoteBuffer.swapInfo.dstToken = dst;
        p.quoteBuffer.swapInfo.inAmount = amount;
        // Send the request to the Chainlink oracle
        sendOperatorRequest(
            req,
            rt.jobInfos[uint256(BSOneInchLib.JobPurpose.QUOTE)].jobFeeInJuels
        );
    }

    function requestChainlinkSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage,
        bytes4 callbackSignature
    ) external override internalOnly {
        if (slippage > 50) {
            revert BSOneInchLib.SlippageIsTooBig(); // A constraint dictated by 1inch Aggregation Protocol
        }

        Chainlink.Request memory req = buildOperatorRequest(
            BSOneInchLib
                .get()
                .rt
                .jobInfos[uint256(BSOneInchLib.JobPurpose.SWAP_CALLDATA)]
                .jobId,
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
                    Strings.toHexString(msg.sender),
                    "&disableEstimate=true"
                )
            )
        );
        req.add("contact", "locus-finance");
        BSOneInchLib.get().p.swapBuffer = BSOneInchLib.SwapInfo({
            srcToken: src,
            dstToken: dst,
            inAmount: amount
        });
        sendOperatorRequest(
            req,
            BSOneInchLib
                .get()
                .rt
                .jobInfos[uint256(BSOneInchLib.JobPurpose.SWAP_CALLDATA)]
                .jobFeeInJuels
        );
    }

    function registerSwapCalldata(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) public override recordChainlinkFulfillment(requestId) {
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.lastSwapCalldata = swapCalldata;
        p.isReadyToFulfillSwap = true;
        emit BSOneInchLib.SwapRegistered(swapCalldata);
    }

    function registerSwapCalldataAndFulfillOnOracleExpense(
        bytes32 requestId,
        bytes memory swapCalldata // KEEP IN MIND SHOULD BE LESS THAN OR EQUAL TO ~500 CHARS.
    ) public override recordChainlinkFulfillment(requestId) {
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.lastSwapCalldata = swapCalldata;
        emit BSOneInchLib.SwapRegistered(swapCalldata);
        IBSOneInchSwapFacet(address(this)).setMaxAllowancesIfNeededAndCheckPayment(
            p.swapBuffer.srcToken,
            p.swapBuffer.inAmount,
            msg.sender
        );
        IBSOneInchSwapFacet(address(this)).fulfillSwapRequest();
    }

    function withdrawLink() external delegatedOnly {
        RolesManagementLib.enforceRole(
            msg.sender,
            RolesManagementLib.STRATEGIST_ROLE
        );
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        if (!link.transfer(msg.sender, link.balanceOf(address(this)))) {
            revert BSOneInchLib.LinkTransferError();
        }
    }
}
