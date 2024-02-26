// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILayerZeroReceiver {
    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external;
}

contract LZEndpointMock {
    uint16 public srcChainId = 1;

    constructor() {}

    function send(
        uint16,
        bytes memory _destination,
        bytes memory _payload,
        address,
        address,
        bytes calldata
    ) external payable {
        address destination = bytesToAddress(_destination);
        bytes memory srcAddress = abi.encodePacked(msg.sender, destination);
        ILayerZeroReceiver(destination).lzReceive(
            srcChainId,
            srcAddress,
            0,
            _payload
        );
    }

    function bytesToAddress(bytes memory _bys)
        public
        pure
        returns (address addr)
    {
        assembly {
            addr := mload(add(_bys, 20))
        }
    }

    function _send(
        uint16,
        bytes memory _destination,
        bytes memory _payload,
        address,
        address,
        bytes calldata _adapterParams
    ) external payable {
        (, uint256 gasFor) = abi.decode(_adapterParams, (uint16, uint256));
        receivePayload(
            srcChainId,
            abi.encode(address(msg.sender)),
            bytesToAddress(_destination),
            0,
            gasFor,
            _payload
        );
    }

    function receivePayload(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        address _dstAddress,
        uint64 _nonce,
        uint256,
        bytes memory _payload
    ) public {
        ILayerZeroReceiver(_dstAddress).lzReceive(
            _srcChainId,
            _srcAddress,
            _nonce,
            _payload
        );
    }
}
