// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ISgBridge {
    error TokenNotSupported(address token, uint16 destChainId);
    error DestinationNotSupported(uint16 destChainId);

    event Bridge(uint16 indexed chainId, uint256 amount);
    event SgReceived(address indexed token, uint256 amount, bool success);

    function initialize(address _router) external;

    function setRouter(address _router) external;

    function setSlippage(uint256 _slippage) external;

    function setWhitelist(address _address) external;

    function setDstGasForCall(uint256 _dstGasForCall) external;

    function setCurrentChainId(uint16 _currentChainId) external;

    function setStargatePoolId(
        address _token,
        uint16 _chainId,
        uint256 _poolId
    ) external;

    function setSupportedDestination(
        uint16 _chainId,
        address _receiveContract
    ) external;

    function revokeFunds() external;

    function bridgeProxy(
        address _token,
        uint256 _amount,
        uint16 _destChainId,
        address _destinationAddress,
        bytes memory _message
    ) external payable;

    function bridge(
        address _token,
        uint256 _amount,
        uint16 _destChainId,
        address _destinationAddress,
        bytes memory _message
    ) external payable;

    function feeForBridge(
        uint16 _destChainId,
        address _destinationContract,
        bytes memory _payload
    ) external view returns (uint256);
}
