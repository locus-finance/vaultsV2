// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";

abstract contract BaseStrategy is IStrategyMessages, NonblockingLzApp {
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
            MessageType.ReportTotalAssets,
            ReportTotalAssetsMessage({
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
        require(msg.sender == strategist, "BaseStrategy::onlyStrategist");
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
        uint64 _nonce,
        bytes memory _payload
    ) internal override {}

    receive() external payable {}
}
