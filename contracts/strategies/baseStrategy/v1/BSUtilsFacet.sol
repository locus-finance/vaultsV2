// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IBSUtilsFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSUtilsFacet is BaseFacet, IBSUtilsFacet {
    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public override view delegatedOnly returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function strategistSignMessageHash() public override view delegatedOnly returns (bytes32) {
        BSLib.Primitives memory p = BSLib.get().p;
        return
            keccak256(
                abi.encodePacked(address(this), p.signNonce, p.currentChainId)
            );
    }

    function verifySignature(bytes memory _signature) external override view delegatedOnly {
        bytes32 messageHash = strategistSignMessageHash();
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        if (ECDSA.recover(ethSignedMessageHash, _signature) != BSLib.get().p.strategist) {
            revert InvalidSignature();
        }
    }

    function withSlippage(uint256 _amount) external override view delegatedOnly returns (uint256) {
        return (_amount * BSLib.get().p.slippage) / BSLib.MAX_BPS;
    }

    function withSlippage(
        uint256 _amount,
        uint256 _slippage
    ) external override view delegatedOnly returns (uint256) {
        return (_amount * _slippage) / BSLib.MAX_BPS;
    }
}