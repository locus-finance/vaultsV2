// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./interfaces/IBSUtilsFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../BSLib.sol";

contract BSUtilsFacet is BaseFacet, IBSUtilsFacet {
    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public override pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function strategistSignMessageHash() public override view returns (bytes32) {
        BSLib.Storage.Primitives memory p = BSLib.get().p;
        return
            keccak256(
                abi.encodePacked(address(this), p.signNonce, p.currentChainId)
            );
    }

    function withSlippage(uint256 _amount) external override view returns (uint256) {
        return (_amount * slippage) / BSLib.MAX_BPS;
    }

    function withSlippage(
        uint256 _amount,
        uint256 _slippage
    ) external override pure returns (uint256) {
        return (_amount * _slippage) / BSLib.MAX_BPS;
    }
}