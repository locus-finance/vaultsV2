// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/LzApp.sol";

abstract contract BaseStrategy is LzApp {
    modifier onlyStrategist() {
        _onlyStrategist();
        _;
    }

    function name() external view virtual returns (string memory);

    function estimatedTotalAssets() public view virtual returns (uint256);

    function adjustPosition(uint256 _debtOutstanding) internal virtual;

    function liquidatePosition(
        uint256 _amountNeeded
    ) internal virtual returns (uint256 _liquidatedAmount, uint256 _loss);

    function liquidateAllPositions()
        internal
        virtual
        returns (uint256 _amountFreed);

    function _onlyStrategist() internal view {
        require(msg.sender == strategist);
    }

    function harvest() external virtual;

    function _blockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal override {}

    address public strategist;
    IERC20 public want;
}
