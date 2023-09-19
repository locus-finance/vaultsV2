// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {NonblockingLzAppUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStrategyMessages} from "../../../interfaces/IStrategyMessages.sol";

import "./interfaces/IBSLiquidatePositionFacet.sol";
import "./interfaces/IBSPrepareMigrationFacet.sol";
import "./interfaces/IBSHandleWithdrawSomeRequestFacet.sol";
import "./interfaces/IBSAdjustPositionFacet.sol";
import "./interfaces/IBSLayerZeroFacet.sol";
import "./interfaces/IBSStargateFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

/// @dev WARNING: `NonblockingLzAppUpgradeable` and the diamond proxy have different `owner()`'s!
/// AND `abstract` modifier for the contract is utilized to force a developer to make this contract a
/// super contract to some strategy. In order to make internal calls work.
contract BSLayerZeroFacet is
    IBSLayerZeroFacet,
    NonblockingLzAppUpgradeable,
    BaseFacet,
    IStrategyMessages
{
    using BytesLib for bytes;
    using SafeERC20 for IERC20Metadata;

    function _initialize(address _lzEndpoint) external override internalOnly {
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal override {
        // Specified `memory` cause there are only read-only operations.
        BSLib.Storage.Primitives memory p = BSLib.get().p;

        if (_srcChainId != p.vaultChainId) {
            revert VaultChainIdMismatch(_srcChainId, p.vaultChainId);
        }

        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );
        if (srcAddress != p.vault) {
            revert VaultAddressMismatch(srcAddress, p.vault);
        }

        _handlePayload(_payload);
    }

    function _handlePayload(bytes memory _payload) internal {
        MessageType messageType = abi.decode(_payload, (MessageType));
        if (messageType == MessageType.AdjustPositionRequest) {
            (, AdjustPositionRequest memory request) = abi.decode(
                _payload,
                (uint256, AdjustPositionRequest)
            );
            IBSAdjustPosition(address(this)).adjustPosition(
                request.debtOutstanding
            );
            emit BSLib.AdjustedPosition(request.debtOutstanding);
        } else if (messageType == MessageType.WithdrawSomeRequest) {
            (, WithdrawSomeRequest memory request) = abi.decode(
                _payload,
                (uint256, WithdrawSomeRequest)
            );
            _handleWithdrawSomeRequest(request);
        } else if (messageType == MessageType.MigrateStrategyRequest) {
            (, MigrateStrategyRequest memory request) = abi.decode(
                _payload,
                (uint256, MigrateStrategyRequest)
            );
            _handleMigrationRequest(request.newStrategy);

            emit BSLib.StrategyMigrated(request.newStrategy);
        }
    }

    function _handleWithdrawSomeRequest(
        WithdrawSomeRequest memory _request
    ) internal {
        BSLib.Storage.ReferenceTypes storage rt = BSLib.get().rt;

        if (rt.withdrawnInEpoch[_request.id]) {
            revert AlreadyWithdrawn();
        }

        (uint256 liquidatedAmount, uint256 loss) = IBSLiquidatePosition(
            address(this)
        ).liquidatePosition(_request.amount);

        bytes memory payload = abi.encode(
            MessageType.WithdrawSomeResponse,
            WithdrawSomeResponse({
                source: address(this),
                amount: liquidatedAmount,
                loss: loss,
                id: _request.id
            })
        );

        if (liquidatedAmount > 0) {
            IBSStargateFacet(address(this)).bridge(
                liquidatedAmount,
                vaultChainId,
                vault,
                payload
            );
        } else {
            _sendMessageToVault(payload);
        }

        rt.withdrawnInEpoch[_request.id] = true;
    }

    function _handleMigrationRequest(address _newStrategy) internal {
        IERC20 want = BSLib.get().p.want;
        IBSPrepareMigrationFacet(address(this)).prepareMigration(_newStrategy);
        want.safeTransfer(_newStrategy, want.balanceOf(address(this)));
    }

    function _sendMessageToVault(bytes memory _payload) internal {
        BSLib.Storage.Primitives memory p = BSLib.get().p;

        bytes memory remoteAndLocalAddresses = abi.encodePacked(
            p.vault,
            address(this)
        );

        // version = 1, gasForDestinationLzReceive = 1_000_000;
        bytes memory adapterParams = abi.encodePacked(1, 1_000_000);

        (uint256 nativeFee, ) = lzEndpoint.estimateFees(
            p.vaultChainId,
            address(this),
            _payload,
            false,
            adapterParams
        );

        if (address(this).balance < nativeFee) {
            revert InsufficientFunds(nativeFee, address(this).balance);
        }

        lzEndpoint.send{value: nativeFee}(
            p.vaultChainId,
            remoteAndLocalAddresses,
            _payload,
            payable(address(this)),
            address(this),
            adapterParams
        );
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external virtual override delegatedOnly {
        address sender = _msgSender();
        if (sender != address(lzEndpoint)) {
            revert InvalidEndpointCaller(sender);
        }
        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }
}
