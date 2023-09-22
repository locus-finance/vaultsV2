// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

import "../diamondBase/libraries/BaseLib.sol";
import "../diamondBase/libraries/InitializerLib.sol";
import "../diamondBase/libraries/PausabilityLib.sol";
import "../diamondBase/libraries/RolesManagementLib.sol";

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library HSLib {
    bytes32 constant HOP_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.hop_strategy");

    address internal constant HOP_ROUTER =
        0x10541b07d8Ad2647Dc6cD67abd4c03575dade261;
    address internal constant STAKING_REWARD =
        0xb0CabFE930642AD3E7DECdc741884d8C3F7EbC70;
    address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant LP = 0xB67c014FA700E69681a673876eb8BAFAA36BFf71;
    address internal constant HOP = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;
    
    address internal constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    struct Storage {
        uint256 requestedQuoteHopToWant;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = HOP_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}