// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {ISgBridge} from "../../../interfaces/ISgBridge.sol";
import {IStargateRouter, IStargateReceiver} from "../../../integrations/stargate/IStargate.sol";
import {IStrategyMessages} from "../../../interfaces/IStrategyMessages.sol";

import "./interfaces/IBSStargateFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSStargateFacet is 
    BaseFacet,
    IStrategyMessages,
    IStargateReceiver,
    IBSStargateFacet
{
    using BytesLib for bytes;
    using SafeERC20 for IERC20Metadata;

    function bridge(
        uint256 _amount,
        uint16 _destChainId,
        address _dest,
        bytes memory _payload
    ) external override internalOnly {
        BSLib.Storage.Primitives memory p = BSLib.get().p;

        uint256 fee = p.sgBridge.feeForBridge(_destChainId, _dest, _payload);
        p.sgBridge.bridge{value: fee}(
            address(p.want)
            _amount,
            _destChainId,
            _dest,
            _payload
        );
    }

    function sgReceive(
        uint16,
        bytes memory _srcAddress,
        uint,
        address _token,
        uint256 _amountLD,
        bytes memory
    ) external override delegatedOnly {
        BSLib.Storage.Primitives memory p = BSLib.get().p;
        
        if (msg.sender != address(p.sgRouter) && msg.sender != address(p.sgBridge)) {
            revert RouterOrBridgeOnly();
        }
        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );

        emit SgReceived(_token, _amountLD, srcAddress);
    }
}