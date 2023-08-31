// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../interfaces/ISwapHelperSubscriber.sol";

contract SwapHelper is AccessControl, ChainlinkClient {
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

    address public constant ONE_INCH_ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 public constant SWAP_AUTHORIZED_ROLE = keccak256("SWAP_AUTHORIZED_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    address public immutable aggregationRouter; // 0x1111111254EEB25477B68fb85Ed929f73A960582

    bytes32 public immutable quoteJobId; // Mumbai - a8356f48569c434eaa4ac5fcb4db5cc0	
    uint256 public immutable quoteJobFee;

    bytes32 public immutable swapCalldataJobId; // Mumbai - 8ced832954544a3c98543c94a51d6a8d
    uint256 public immutable swapCalldataJobFee;

    address public lastQuotedSrcToken;
    address public lastQuotedDstToken;
    uint256 public lastQuotedSrcTokenAmount;

    address public lastSwapSrcToken;
    address public lastSwapDstToken;
    uint256 public lastSwapSrcTokenAmount;
    bool public isReadyToFulfillSwap;
    bytes internal _lastSwapCalldata;

    string public oneInchApiKey;
    EnumerableSet.AddressSet internal _subscribers;
    
    constructor(
        uint256 _quoteJobFee,
        uint256 _swapCalldataJobFee,
        bytes32 _quoteJobId,
        bytes32 _swapCalldataJobId,
        address _strategist,
        address _aggregationRouter,
        address chainlinkTokenAddress, // Mumbai - 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
        address chainlinkOracleAddress, // Mumbai - 0x12A3d7759F745f4cb8EE8a647038c040cB8862A5
        string memory _oneInchApiKey, // sc2uJVR5JYtl05ddY2Iryp9tq89jVjnh
        address[] memory authorizedToSwap
    )
        ConfirmedOwner(_msgSender())
    {
        setChainlinkToken(chainlinkTokenAddress);
        setChainlinkOracle(chainlinkOracleAddress);
        quoteJobFee = _quoteJobFee; // SHOULD BE PART OF LINK_DIVISIBILITY CONSTANT
        swapCalldataJobFee = _swapCalldataJobFee; // SHOULD BE PART OF LINK_DIVISIBILITY CONSTANT
        quoteJobId = _quoteJobId;
        swapCalldataJobId = _swapCalldataJobId;
        oneInchApiKey = _oneInchApiKey;
        aggregationRouter = _aggregationRouter;
        for (uint8 i = 0; i < authorizedToSwap.length; i++) {
            _grantRole(SWAP_AUTHORIZED_ROLE, authorizedToSwap[uint256(i)]);
        }
        _grantRole(STRATEGIST_ROLE, _strategist);
    }

    function addSubscriber(address subscriber) external onlyRole(STRATEGIST_ROLE) {
        if (!_subscribers.add(subscriber)) {
            revert CannotAddSubscriber();
        }
    }

    function removeSubscriber(address subscriber) external onlyRole(STRATEGIST_ROLE) {
        if (!_subscribers.remove(subscriber)) {
            revert CannotRemoveSubscriber();
        }
    }

    function subscriberAt(uint256 subscriberIdx) external view returns (address) {
        return _subscribers.at(subscriberIdx);
    }

    function subscribersLength() external view returns (uint256) {
        return _subscribers.length();
    }

    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external onlyRole(SWAP_AUTHORIZED_ROLE) {
        Chainlink.Request memory req = buildChainlinkRequest(
            quoteJobId,
            address(this),
            this.fulfillQuoteRequest.selector
        );
        req.add('method', 'GET');
        req.add(
            'url', 
            string(
                abi.encodePacked(
                    'https://api.1inch.dev/swap/v5.2/1/quote?src=', 
                    Strings.toHexString(src),
                    "&dst=",
                    Strings.toHexString(dst),
                    "&amount=",
                    Strings.toString(amount)
                )
            )
        );
        req.add('headers', string(abi.encodePacked(
            '["accept", "application/json", "Authorization", "Bearer ',
            oneInchApiKey,
            '"]'
        )));
        req.add('contact', 'numert');
        req.add('path', "toAmount");
        lastQuotedSrcToken = src;
        lastQuotedDstToken = dst;
        lastQuotedSrcTokenAmount = amount;
        sendChainlinkRequest(req, quoteJobFee);
    }

    function fulfillQuoteRequest(
        bytes32 requestId,
        uint256 toAmount
    ) public recordChainlinkFulfillment(requestId)  {
        emit QuoteReceived(
            lastQuotedSrcToken, 
            lastQuotedDstToken, 
            toAmount, 
            lastQuotedSrcTokenAmount
        );
        uint256 length = _subscribers.length(); 
        for (uint256 i = 0; i < length; i++) {
            ISwapHelperSubscriber(_subscribers.at(i)).notify(
                lastQuotedSrcToken,
                lastQuotedDstToken,
                toAmount,
                lastQuotedSrcTokenAmount
            );
        }
    }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable onlyRole(SWAP_AUTHORIZED_ROLE) {
        if (slippage > 50) {
            revert SlippageIsTooBig(); // A constraint dictated by 1inch Aggregation Protocol
        }
        if (src == ONE_INCH_ETH_ADDRESS && amount < msg.value) {
            revert NotEnoughNativeTokensSent();
        }
        isReadyToFulfillSwap = false; // double check if the flag is down

        address sender = _msgSender();
        IERC20 srcErc20 = IERC20(src);
        srcErc20.safeTransferFrom(sender, address(this), amount);

        // make sure if allowances are at max so we would make cheaper future txs
        if (srcErc20.allowance(address(this), aggregationRouter) < amount) {
            srcErc20.approve(aggregationRouter, type(uint256).max);
        }
        IERC20 dstErc20 = IERC20(src);
        if (dstErc20.allowance(address(this), aggregationRouter) < amount) {
            dstErc20.approve(aggregationRouter, type(uint256).max);
        }

        Chainlink.Request memory req = buildChainlinkRequest(
            swapCalldataJobId,
            address(this),
            this.registerSwapCalldata.selector
        );
        req.add('method', 'GET');
        req.add(
            'url', 
            string(
                abi.encodePacked(
                    'https://api.1inch.dev/swap/v5.2/1/swap?src=', 
                    Strings.toHexString(src),
                    "&dst=",
                    Strings.toHexString(dst),
                    "&amount=",
                    Strings.toString(amount),
                    "&from=",
                    Strings.toHexString(_msgSender()),
                    "&slippage=",
                    Strings.toString(slippage),
                    "&disableEstimate=true"
                )
            )
        );
        req.add('headers', string(abi.encodePacked(
            '["accept", "application/json", "Authorization", "Bearer ',
            oneInchApiKey,
            '"]'
        )));
        req.add('contact', 'numert');
        req.add('path', "tx,data");
        lastSwapSrcToken = src;
        lastSwapDstToken = dst;
        lastSwapSrcTokenAmount = amount;
        sendChainlinkRequest(req, swapCalldataJobFee);
    }

    function registerSwapCalldata(
        bytes32 requestId,
        bytes memory swapCalldata
    ) public recordChainlinkFulfillment(requestId) {
        _lastSwapCalldata = swapCalldata;
        isReadyToFulfillSwap = true;
        emit SwapRegistered(swapCalldata);
    }

    function fulfillSwap() external onlyRole(STRATEGIST_ROLE) {
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

    function evacuateLinkTokens() external onlyRole(STRATEGIST_ROLE) {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        if (!link.transfer(msg.sender, link.balanceOf(address(this)))) {
            revert TransferError();
        }
    }

    receive() external payable {}
}