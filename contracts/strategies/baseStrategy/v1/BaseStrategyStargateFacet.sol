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

import "../../diamondBase/facets/BaseFacet.sol";

contract BaseStrategyStargateFacet is 
    BaseFacet,
    IStrategyMessages,
    IStargateReceiver 
{
    using BytesLib for bytes;
    using SafeERC20 for IERC20Metadata;

    function sgReceive(
        uint16,
        bytes memory _srcAddress,
        uint,
        address _token,
        uint256 _amountLD,
        bytes memory
    ) external override {

    }
}