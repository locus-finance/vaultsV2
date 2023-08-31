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

    error TransferError();
    error SlippageIsTooBig();
    error NotEnoughNativeTokensSent();
    error CannotAddSubscriber();
    error CannotRemoveSubscriber();
    error SwapOperationIsNotReady();

    event QuoteReceived(
        address indexed src,
        address indexed dst,
        uint256 indexed amountOut,
        uint256 amountIn
    );
    event SwapPerformed(
        address indexed src,
        address indexed dst,
        uint256 indexed amountIn
    );
    event SwapRegistered(bytes indexed swapCalldata);

    address public constant ONE_INCH_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 public constant SWAP_AUTHORIZED_ROLE =
        keccak256("SWAP_AUTHORIZED_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    address public immutable aggregationRouter;

    address internal oracleAddress;
    bytes32 internal jobId;
    uint256 internal fee;

    address public lastQuotedSrcToken;
    address public lastQuotedDstToken;
    uint256 public lastQuotedSrcTokenAmount;

    address public lastSwapSrcToken;
    address public lastSwapDstToken;
    uint256 public lastSwapSrcTokenAmount;
    bool public isReadyToFulfillSwap;
    bytes internal _lastSwapCalldata;

    EnumerableSet.AddressSet internal _subscribers;

    constructor(
        uint256 _jobFee, // Mainnet- 140 == 1.4 LINK
        address _strategist,
        address _aggregationRouter, // Mainnet - 0x1111111254EEB25477B68fb85Ed929f73A960582
        address chainlinkTokenAddress, // Mainnet - 0x514910771AF9Ca656af840dff83E8264EcF986CA
        address chainlinkOracleAddress, // Mainnet - 0x0168B5FcB54F662998B0620b9365Ae027192621f
        string memory _jobId, // Mainnet - 0eb8d4b227f7486580b6f66706ac5d47
        address[] memory authorizedToSwap
    ) {
        _grantRole(STRATEGIST_ROLE, _strategist);
        setChainlinkToken(chainlinkTokenAddress);
        setOracleAddress(chainlinkOracleAddress);
        setJobId(_jobId);
        setFeeInHundredthsOfLink(_jobFee);
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

    // Update jobId
    function setJobId(string memory _jobId) public onlyRole(STRATEGIST_ROLE) {
        jobId = bytes32(bytes(_jobId));
    }

    function getJobId()
        public
        view
        onlyRole(STRATEGIST_ROLE)
        returns (string memory)
    {
        return string(abi.encodePacked(jobId));
    }

    // Update fees
    function setFeeInJuels(
        uint256 _feeInJuels
    ) public onlyRole(STRATEGIST_ROLE) {
        fee = _feeInJuels;
    }

    function setFeeInHundredthsOfLink(
        uint256 _feeInHundredthsOfLink
    ) public onlyRole(STRATEGIST_ROLE) {
        setFeeInJuels((_feeInHundredthsOfLink * LINK_DIVISIBILITY) / 100);
    }

    function getFeeInHundredthsOfLink()
        public
        view
        onlyRole(STRATEGIST_ROLE)
        returns (uint256)
    {
        return (fee * 100) / LINK_DIVISIBILITY;
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

    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override onlyRole(SWAP_AUTHORIZED_ROLE) {
        Chainlink.Request memory req = buildOperatorRequest(
            jobId,
            this.fulfillQuoteRequest.selector
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
        req.add(
            "headers",
            '["accept", "application/json", "Authorization", "Bearer ${SECRET_01}"]'
        );
        req.add("body", "");
        req.add("contact", "locus-finance");
        req.add("path", "toAmount");
        lastQuotedSrcToken = src;
        lastQuotedDstToken = dst;
        lastQuotedSrcTokenAmount = amount;
        // Send the request to the Chainlink oracle
        sendOperatorRequest(req, fee);
    }

    function fulfillQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) public recordChainlinkFulfillment(requestId) {
        uint256 length = _subscribers.length();
        for (uint256 i = 0; i < length; i++) {
            ISwapHelperSubscriber(_subscribers.at(i)).notify(
                lastQuotedSrcToken,
                lastQuotedDstToken,
                toAmount,
                lastQuotedSrcTokenAmount
            );
        }
        emit QuoteReceived(
            lastQuotedSrcToken,
            lastQuotedDstToken,
            toAmount,
            lastQuotedSrcTokenAmount
        );
    }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override onlyRole(SWAP_AUTHORIZED_ROLE) {
        if (slippage > 50) {
            revert SlippageIsTooBig(); // A constraint dictated by 1inch Aggregation Protocol
        }
        isReadyToFulfillSwap = false; // double check if the flag is down

        address sender = _msgSender();
        IERC20 srcErc20 = IERC20(src);
        if (src == ONE_INCH_ETH_ADDRESS) {
            if (amount < msg.value) {
                revert NotEnoughNativeTokensSent();
            }
        } else {
            srcErc20.safeTransferFrom(sender, address(this), amount);
            // make sure if allowances are at max so we would make cheaper future txs
            if (srcErc20.allowance(address(this), aggregationRouter) < amount) {
                srcErc20.approve(aggregationRouter, type(uint256).max);
            }
        }

        Chainlink.Request memory req = buildOperatorRequest(
            jobId,
            this.registerSwapCalldata.selector
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
        req.add(
            "headers",
            '["accept", "application/json", "Authorization", "Bearer ${SECRET_01}"]'
        );
        req.add("body", "");
        req.add("contact", "locus-finance");
        req.add("path", "tx,data");
        lastSwapSrcToken = src;
        lastSwapDstToken = dst;
        lastSwapSrcTokenAmount = amount;
        sendOperatorRequest(req, fee);
    }

    function registerSwapCalldata(
        bytes32 requestId,
        bytes memory swapCalldata
    ) public recordChainlinkFulfillment(requestId) {
        _lastSwapCalldata = swapCalldata;
        isReadyToFulfillSwap = true;
        emit SwapRegistered(swapCalldata);
    }

    function fulfillSwap() external override onlyRole(STRATEGIST_ROLE) {
        if (!isReadyToFulfillSwap) {
            revert SwapOperationIsNotReady();
        }
        if (lastSwapSrcToken == ONE_INCH_ETH_ADDRESS) {
            aggregationRouter.functionCallWithValue(
                _lastSwapCalldata,
                lastSwapSrcTokenAmount
            );
        } else {
            aggregationRouter.functionCall(_lastSwapCalldata);
        }
        emit SwapPerformed(
            lastSwapSrcToken,
            lastSwapDstToken,
            lastSwapSrcTokenAmount
        );
        isReadyToFulfillSwap = false;
    }

    function withdrawLink() public onlyRole(STRATEGIST_ROLE) {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        if (!link.transfer(_msgSender(), link.balanceOf(address(this)))) {
            revert TransferError();
        }
    }

    receive() external payable {}
}
