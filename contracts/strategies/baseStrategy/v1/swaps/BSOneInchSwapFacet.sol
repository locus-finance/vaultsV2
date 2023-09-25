// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../diamondBase/libraries/RolesManagementLib.sol";
import "../../../diamondBase/facets/BaseFacet.sol";
import "../../BSLib.sol";
import "./libraries/BSOneInchLib.sol";
import "../interfaces/IBSOneInchSwapFacet.sol";
import "../interfaces/IBSChainlinkFacet.sol";
import "../interfaces/forSpecificStrategies/IBSEmergencySwapOrQuoteFacet.sol";

contract BSOneInchSwapFacet is BaseFacet, IBSOneInchSwapFacet {
    using SafeERC20 for IERC20;
    using Address for address;

    function setMaxAllowancesIfNeededAndCheckPayment(
        address src,
        uint256 amount,
        address sender
    ) public payable override internalOnly {
        IERC20 srcErc20 = IERC20(src);
        if (src == BSOneInchLib.ONE_INCH_ETH_ADDRESS) {
            if (msg.value != amount) {
                revert BSOneInchLib.NotEnoughNativeTokensSent();
            }
        } else {
            address aggregationRouter = BSOneInchLib.get().p.aggregationRouter;
            srcErc20.safeTransferFrom(sender, address(this), amount);
            // make sure if allowances are at max so we would make cheaper future txs
            if (srcErc20.allowance(address(this), aggregationRouter) < amount) {
                srcErc20.approve(aggregationRouter, type(uint256).max);
            }
        }
    }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override internalOnly {
        BSOneInchLib.get().p.isReadyToFulfillSwap = false; // double check if the flag is down
        _requestSwap(
            src,
            dst,
            amount,
            slippage,
            IBSChainlinkFacet.registerSwapCalldata.selector
        );
    }

    function requestSwapAndFulfillOnOracleExpense(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override internalOnly {
        BSOneInchLib.get().p.isReadyToFulfillSwap = false; // double check if the flag is down
        _requestSwap(
            src,
            dst,
            amount,
            slippage,
            IBSChainlinkFacet
                .registerSwapCalldataAndFulfillOnOracleExpense
                .selector
        );
    }

    /// @dev Only to be used in either strategist intervention or an Oracle execution.
    function fulfillSwapRequest() public override internalOnly {
        BSOneInchLib.Primitives memory p = BSOneInchLib.get().p;
        if (p.swapBuffer.srcToken == BSOneInchLib.ONE_INCH_ETH_ADDRESS) {
            p.aggregationRouter.functionCallWithValue(
                p.lastSwapCalldata,
                p.swapBuffer.inAmount
            );
        } else {
            p.aggregationRouter.functionCall(p.lastSwapCalldata);
        }
        emit BSOneInchLib.SwapPerformed(p.swapBuffer);
    }

    function fulfillSwap() external override internalOnly {
        if (!BSOneInchLib.get().p.isReadyToFulfillSwap) {
            revert BSOneInchLib.SwapOperationIsNotReady();
        }
        fulfillSwapRequest();
        BSOneInchLib.get().p.isReadyToFulfillSwap = false;
    }

    function strategistFulfillSwap(
        bytes memory _swapCalldata
    ) external payable override {
        RolesManagementLib.enforceSenderRole(
            RolesManagementLib.STRATEGIST_ROLE
        );
        BSOneInchLib.Primitives storage p = BSOneInchLib.get().p;
        p.isReadyToFulfillSwap = false;
        p.lastSwapCalldata = _swapCalldata;
        setMaxAllowancesIfNeededAndCheckPayment(
            p.swapBuffer.srcToken,
            p.swapBuffer.inAmount,
            msg.sender
        );
        fulfillSwapRequest();
        emit BSOneInchLib.StrategistInterferred(
            BSOneInchLib
                .StrategistInterference
                .SWAP_CALLDATA_REQUEST_PEROFRMED_MANUALLY
        );
    }

    function _requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage,
        bytes4 callbackSignature
    ) internal {
        setMaxAllowancesIfNeededAndCheckPayment(src, amount, msg.sender);
        try
            IBSChainlinkFacet(address(this)).requestChainlinkSwap(
                src,
                dst,
                amount,
                slippage,
                callbackSignature
            )
        {
            emit BSOneInchLib.Swap(
                BSOneInchLib.SwapInfo({
                    srcToken: src,
                    dstToken: dst,
                    inAmount: amount
                })
            );
        } catch (bytes memory lowLevelErrorData) {
            if (src == BSOneInchLib.ONE_INCH_ETH_ADDRESS) {
                IBSEmergencySwapOrQuoteFacet(address(this))
                    .emergencyRequestSwap{value: msg.value}(
                    src,
                    dst,
                    amount,
                    slippage
                );
            } else {
                IBSEmergencySwapOrQuoteFacet(address(this))
                    .emergencyRequestSwap(src, dst, amount, slippage);
            }
            emit BSOneInchLib.EmergencySwap(
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
