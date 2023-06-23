// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";

abstract contract BaseStrategy is IStrategyMessages, NonblockingLzApp {
    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);

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
        address _sgBridge
    ) NonblockingLzApp(_lzEndpoint) {
        strategist = _strategist;
        want = _want;
        vaultChainId = _vaultChainId;
        vault = _vault;
        sgBridge = ISgBridge(_sgBridge);
    }

    address public strategist;
    IERC20 public want;
    address public vault;
    uint16 public vaultChainId;
    ISgBridge public sgBridge;

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

        MessageType _messageType = abi.decode(_payload, (MessageType));
        if (_messageType == MessageType.WithdrawSomeRequest) {
            (, WithdrawSomeRequest memory _message) = abi.decode(
                _payload,
                (uint256, WithdrawSomeRequest)
            );
            (uint256 _liquidatedAmount, uint256 _loss) = _liquidatePosition(
                _message.amount
            );
            sgBridge.bridge(
                address(want),
                _liquidatedAmount,
                vaultChainId,
                vault,
                abi.encode(
                    WithdrawSomeResponse({
                        source: address(this),
                        amount: _liquidatedAmount,
                        loss: _loss,
                        id: _message.id
                    })
                )
            );
        } else if (_messageType == MessageType.WithdrawAllRequest) {
            (, WithdrawAllRequest memory _message) = abi.decode(
                _payload,
                (uint256, WithdrawAllRequest)
            );
            uint256 _amountFreed = _liquidateAllPositions();
            sgBridge.bridge(
                address(want),
                _amountFreed,
                vaultChainId,
                vault,
                abi.encode(
                    WithdrawAllResponse({
                        source: address(this),
                        amount: _amountFreed,
                        id: _message.id
                    })
                )
            );
        } else {
            revert IncorrectMessageType(uint256(_messageType));
        }
    }

    receive() external payable {}
}
