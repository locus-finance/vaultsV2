// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeMock {
    uint256 public lastBridge;

    constructor() {}

    function bridge(
        address _token,
        uint256 _amount,
        uint16,
        address _destinationAddress,
        address,
        bytes calldata
    ) external {
        uint256 usdcBalance = IERC20(_token).balanceOf(address(this));
        require(
            IERC20(_token).transfer(_destinationAddress, usdcBalance),
            "BridgeMock funds transfer failed"
        );
        lastBridge = _amount;
    }

    function swap(
        address,
        address,
        uint256 _amountA,
        address
    ) external pure returns (bool a, uint256 v) {
        a = true;
        v = _amountA;
    }

    function getChainID() internal view returns (uint16) {
        uint16 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
