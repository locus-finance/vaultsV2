// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NonblockingLzAppUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";

abstract contract BaseStrategy is
    Initializable,
    NonblockingLzAppUpgradeable,
    IStrategyMessages,
    IStargateReceiver
{
    using BytesLib for bytes;

    error InsufficientFunds(uint256 amount, uint256 balance);
    error IncorrectMessageType(uint256 messageType);
    error ReceiveForbidden(address sender);

    event SgReceived(address indexed token, uint256 amount, address sender);

    modifier onlyStrategist() {
        _onlyStrategist();
        _;
    }

    modifier onlyStrategistOrSelf() {
        _onlyStrategistOrSelf();
        _;
    }

    function __BaseStrategy_init(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _router
    ) internal onlyInitializing {
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);

        strategist = _strategist;
        want = _want;
        vaultChainId = _vaultChainId;
        vault = _vault;
        sgBridge = ISgBridge(_sgBridge);
        router = IStargateRouter(_router);

        want.approve(address(sgBridge), type(uint256).max);
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

    function revokeFunds() external onlyStrategist {
        payable(strategist).transfer(address(this).balance);
    }

    function reportTotalAssets() public virtual onlyStrategistOrSelf {
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
            _getAdapterParams()
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
            _getAdapterParams()
        );
    }

    function _getAdapterParams() internal view virtual returns (bytes memory) {
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 500_000;
        return abi.encodePacked(version, gasForDestinationLzReceive);
    }

    function _onlyStrategist() internal view {
        require(msg.sender == strategist, "BaseStrategy::OnlyStrategist");
    }

    function _onlyStrategistOrSelf() internal view {
        require(
            msg.sender == strategist || msg.sender == address(this),
            "BaseStrategy::OnlyStrategistOrSelf"
        );
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
        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );
        require(srcAddress == vault, "BaseStrategy::VaultAddressMismatch");

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
                    MessageType.WithdrawSomeResponse,
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
                    MessageType.WithdrawAllResponse,
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

    function callMe() external {
        sgBridge.bridge(
            address(want),
            0.1 ether,
            vaultChainId,
            vault,
            abi.encode(
                MessageType.WithdrawAllResponse,
                WithdrawAllResponse({
                    source: address(this),
                    amount: 1 ether,
                    id: 1
                })
            )
        );
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
        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );
        emit SgReceived(_token, _amountLD, srcAddress);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual override {
        require(
            msg.sender == address(lzEndpoint),
            "BaseStrategy::InvalidEndpointCaller"
        );

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    receive() external payable {}
}
