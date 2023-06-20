// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IStargateRouter, IStargateReceiver} from "./interfaces/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";

contract SgBridge is OwnableUpgradeable, ISgBridge, IStargateReceiver {
    using SafeERC20 for IERC20;

    IStargateRouter public router;

    uint256 public slippage;
    uint256 public dstGasForCall;
    uint16 public currentChainId;

    mapping(address => mapping(uint16 => uint256)) public poolIds;
    mapping(uint16 => address) public supportedDestinations;

    function initialize(address _router) public override initializer {
        __Ownable_init();

        router = IStargateRouter(_router);
        slippage = 9_900;
        dstGasForCall = 500_000;
    }

    function setSlippage(uint256 _slippage) external override onlyOwner {
        slippage = _slippage;
    }

    function setDstGasForCall(
        uint256 _dstGasForCall
    ) external override onlyOwner {
        dstGasForCall = _dstGasForCall;
    }

    function setCurrentChainId(
        uint16 _currentChainId
    ) external override onlyOwner {
        currentChainId = _currentChainId;
    }

    function setStargatePoolId(
        address token,
        uint16 chainId,
        uint256 poolId
    ) external override onlyOwner {
        IERC20(token).approve(address(router), type(uint256).max);
        poolIds[token][chainId] = poolId;
    }

    function setSupportedDestination(
        uint16 chainId,
        address receiveContract
    ) external override onlyOwner {
        supportedDestinations[chainId] = receiveContract;
    }

    function bridge(
        address token,
        uint256 amount,
        uint16 destChainId,
        address destinationAddress,
        bytes memory message
    ) external payable override {
        uint256 destinationPool = poolIds[token][destChainId];
        if (destinationPool == 0) {
            revert TokenNotSupported(token, destChainId);
        }

        uint256 sourcePool = poolIds[token][currentChainId];
        if (sourcePool == 0) {
            revert TokenNotSupported(token, currentChainId);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (currentChainId == destChainId) {
            IERC20(token).safeTransfer(destinationAddress, amount);
            return;
        }

        address receiveContract = supportedDestinations[destChainId];
        if (receiveContract == address(0)) {
            revert DestinationNotSupported(destChainId);
        }

        _bridgeInternal(
            amount,
            sourcePool,
            destChainId,
            destinationPool,
            destinationAddress,
            receiveContract,
            message
        );
    }

    function sgReceive(
        uint16,
        bytes memory,
        uint,
        address token,
        uint256 amountLD,
        bytes memory payload
    ) external override {
        if (msg.sender != address(router)) {
            revert ReceiveForbidden(msg.sender);
        }

        (address toAddr, bytes memory message) = abi.decode(
            payload,
            (address, bytes)
        );

        IERC20(token).safeTransfer(toAddr, amountLD);
        (bool success, ) = toAddr.call(message);

        emit SgReceived(token, amountLD, success);
    }

    function _bridgeInternal(
        uint256 amount,
        uint256 srcPoolId,
        uint16 destChainId,
        uint256 destinationPoolId,
        address destinationAddress,
        address destinationContract,
        bytes memory message
    ) internal {
        bytes memory payload = abi.encode(destinationAddress, message);
        uint256 withSlippage = (amount * slippage) / 10_000;

        router.swap{value: msg.value}(
            destChainId,
            srcPoolId,
            destinationPoolId,
            payable(msg.sender),
            amount,
            withSlippage,
            _getLzParams(),
            abi.encodePacked(destinationContract),
            payload
        );

        emit Bridge(destChainId, amount);
    }

    function _getLzParams()
        internal
        view
        returns (IStargateRouter.LzTxObj memory)
    {
        return
            IStargateRouter.LzTxObj({
                dstGasForCall: dstGasForCall,
                dstNativeAmount: 0,
                dstNativeAddr: abi.encode(address(this))
            });
    }
}
