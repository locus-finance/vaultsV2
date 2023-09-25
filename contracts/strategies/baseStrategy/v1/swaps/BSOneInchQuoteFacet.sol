// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Address.sol";

import "../../../diamondBase/libraries/RolesManagementLib.sol";
import "../../../diamondBase/facets/BaseFacet.sol";
import "../../BSLib.sol";
import "./libraries/BSOneInchLib.sol";
import "../interfaces/forSpecificStrategies/IBSQuoteNotifiableFacet.sol";
import "../interfaces/IBSChainlinkFacet.sol";
import "../interfaces/forSpecificStrategies/IBSEmergencySwapOrQuoteFacet.sol";
import "../interfaces/IBSOneInchQuoteFacet.sol";

contract BSOneInchQuoteFacet is BaseFacet, IBSOneInchQuoteFacet {
    using Address for address;

    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override internalOnly returns (uint256) {
        BSOneInchLib.get().p.isReadyToFulfillQuote = false; // double check the flag
        _requestQuote(
            src,
            dst,
            amount,
            IBSChainlinkFacet.registerQuoteRequest.selector
        );
        // THE RETURN VALUE MUST BE IGNORED BECAUSE IT IS HANDLED BY THE ORACLE
        return 0;
    }

    function requestQuoteAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount
    ) external override internalOnly {
        _requestQuote(
            src,
            dst,
            amount,
            IBSChainlinkFacet
                .registerQuoteAndFulfillRequestOnOracleExpense
                .selector
        );
    }

    function fulfillQuoteRequest() public override internalOnly {
        BSOneInchLib.Primitives memory p = BSOneInchLib.get().p;
        IBSQuoteNotifiableFacet(address(this)).notifyCallback(
            p.quoteBuffer.swapInfo.srcToken,
            p.quoteBuffer.swapInfo.dstToken,
            p.quoteBuffer.outAmount,
            p.quoteBuffer.swapInfo.inAmount
        );
        emit BSOneInchLib.QuoteSent(p.quoteBuffer);
    }

    function fulfillQuote() external override internalOnly {
        if (!BSOneInchLib.get().p.isReadyToFulfillQuote) {
            revert BSOneInchLib.QuoteOperationIsNotReady();
        }
        fulfillQuoteRequest();
        BSOneInchLib.get().p.isReadyToFulfillQuote = false;
    }

    function strategistFulfillQuote(
        uint256 toAmount
    ) external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(
            RolesManagementLib.STRATEGIST_ROLE
        );
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.isReadyToFulfillQuote = false; // reset the flag
        p.quoteBuffer.outAmount = toAmount;
        emit BSOneInchLib.QuoteRegistered(toAmount);
        fulfillQuoteRequest();
        emit BSOneInchLib.StrategistInterferred(
            BSOneInchLib.StrategistInterference.QUOTE_REQUEST_PERFORMED_MANUALLY
        );
    }

    function _requestQuote(
        address src,
        address dst,
        uint256 amount,
        bytes4 callbackSignature
    ) internal {
        try
            IBSChainlinkFacet(address(this)).requestChainlinkQuote(
                src,
                dst,
                amount,
                callbackSignature
            )
        {
            emit BSOneInchLib.Quote(
                BSOneInchLib.SwapInfo({
                    srcToken: src,
                    dstToken: dst,
                    inAmount: amount
                })
            );
        } catch (bytes memory lowLevelErrorData) {
            bytes memory result = address(this).functionStaticCall(
                abi.encodePacked(
                    IBSEmergencySwapOrQuoteFacet.emergencyRequestQuote.selector,
                    src,
                    dst,
                    amount
                )
            );
            BSOneInchLib.get().p.quoteBuffer.outAmount = abi.decode(
                result,
                (uint256)
            );
            emit BSOneInchLib.EmergencyQuote(
                BSOneInchLib.SwapInfo({
                    srcToken: src,
                    dstToken: dst,
                    inAmount: amount
                }),
                lowLevelErrorData
            );
        }
    }
}
