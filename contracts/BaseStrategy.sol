// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";

abstract contract BaseStrategy is
    IStrategyMessages,
    IStargateReceiver,
    NonblockingLzApp
{
    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);
    error ReceiveForbidden(address sender);

    event SgReceived(address indexed token, uint256 amount, address sender);

    modifier onlyStrategist() {
        _onlyStrategist();
        _;
    }

    constructor(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _router
    ) NonblockingLzApp(_lzEndpoint) {
        strategist = _strategist;
        want = _want;
        vaultChainId = _vaultChainId;
        vault = _vault;
        sgBridge = ISgBridge(_sgBridge);
        router = IStargateRouter(_router);
    }

    address public strategist;
    IERC20 public want;
    address public vault;
    uint16 public vaultChainId;
    ISgBridge public sgBridge;
    IStargateRouter public router;

    function name() external view virtual returns (string memory);

    function harvest() external virtual;

    function estimatedTotalAssets() public view virtual returns (uint256);

    function reportTotalAssets() public virtual onlyStrategist {
        bytes memory payload = abi.encode(
            MessageType.ReportTotalAssetsResponse,
            ReportTotalAssetsResponse({
                source: address(this),
                timestamp: block.timestamp,
                totalAssets: estimatedTotalAssets()
            })
        );
        bytes memory remoteAndLocalAddresses = abi.encodePacked(
            vault,
            address(this)
        );

        (uint256 nativeFee, ) = lzEndpoint.estimateFees(
            vaultChainId,
            address(this),
            payload,
            false,
            bytes("")
        );

        if (address(this).balance < nativeFee) {
            revert InsufficientFunds(nativeFee, address(this).balance);
        }

        lzEndpoint.send{value: nativeFee}(
            vaultChainId,
            remoteAndLocalAddresses,
            payload,
            payable(address(this)),
            address(this),
            bytes("")
        );
    }

    function _onlyStrategist() internal view {
        require(msg.sender == strategist, "BaseStrategy::OnlyStrategist");
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal virtual returns (uint256 _liquidatedAmount, uint256 _loss);

    function _liquidateAllPositions()
        internal
        virtual
        returns (uint256 _amountFreed);

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal override {
        require(
            _srcChainId == vaultChainId,
            "BaseStrategy::VaultChainIdMismatch"
        );
        require(
            keccak256(_srcAddress) ==
                keccak256(trustedRemoteLookup[_srcChainId]),
            "BaseStrategy::TrustedAddressMismatch"
        );

        MessageType messageType = abi.decode(_payload, (MessageType));
        if (messageType == MessageType.WithdrawSomeRequest) {
            (, WithdrawSomeRequest memory message) = abi.decode(
                _payload,
                (uint256, WithdrawSomeRequest)
            );
            (uint256 liquidatedAmount, uint256 loss) = _liquidatePosition(
                message.amount
            );
            sgBridge.bridge(
                address(want),
                liquidatedAmount,
                vaultChainId,
                vault,
                abi.encode(
                    WithdrawSomeResponse({
                        source: address(this),
                        amount: liquidatedAmount,
                        loss: loss,
                        id: message.id
                    })
                )
            );
        } else if (messageType == MessageType.WithdrawAllRequest) {
            (, WithdrawAllRequest memory message) = abi.decode(
                _payload,
                (uint256, WithdrawAllRequest)
            );
            uint256 amountFreed = _liquidateAllPositions();
            sgBridge.bridge(
                address(want),
                amountFreed,
                vaultChainId,
                vault,
                abi.encode(
                    WithdrawAllResponse({
                        source: address(this),
                        amount: amountFreed,
                        id: message.id
                    })
                )
            );
        } else if (messageType == MessageType.ReportTotalAssetsRequest) {
            reportTotalAssets();
        } else {
            revert IncorrectMessageType(uint256(messageType));
        }
    }

    function sgReceive(
        uint16,
        bytes memory _srcAddress,
        uint,
        address _token,
        uint256 _amountLD,
        bytes memory
    ) external override {
        require(msg.sender == address(router), "SgBridge::RouterOnly");
        address srcAddress = abi.decode(_srcAddress, (address));
        emit SgReceived(_token, _amountLD, srcAddress);
    }

    receive() external payable {}
}
