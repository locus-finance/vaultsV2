// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {NonblockingLzAppUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStrategyMessages} from "../../../interfaces/IStrategyMessages.sol";

import "../interfaces/IBaseStrategyLayerZeroFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

/// @dev WARNING: `NonblockingLzAppUpgradeable` and the diamond proxy have different `owner()`'s!
/// AND `abstract` modifier for the contract is utilized to force a developer to make this contract a
/// super contract to some strategy. In order to make internal calls work.
abstract contract BaseStrategyLayerZeroFacet is
    IBaseStrategyLayerZeroFacet,
    NonblockingLzAppUpgradeable,
    BaseFacet,
    IStrategyMessages
{
    using BytesLib for bytes;
    using SafeERC20 for IERC20Metadata;

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
            _adjustPosition(request.debtOutstanding);

            emit AdjustedPosition(request.debtOutstanding);
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

            emit StrategyMigrated(request.newStrategy);
        }
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual override delegatedOnly {
        address sender = _msgSender();
        if (sender != address(lzEndpoint)) {
            revert InvalidEndpointCaller(sender);
        }
        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }
}
