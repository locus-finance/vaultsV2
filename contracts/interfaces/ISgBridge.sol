// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ISgBridge {
    event Bridge(uint16 indexed chainId, uint256 amount);

    function setSlippage(uint256 _slippage) external;
}
