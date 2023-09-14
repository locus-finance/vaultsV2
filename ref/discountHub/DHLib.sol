// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

import "../base/libraries/BaseLib.sol";
import "../base/libraries/InitializerLib.sol";
import "../base/libraries/PausabilityLib.sol";
import "../base/libraries/RolesManagementLib.sol";

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library DHLib {
    bytes32 constant DISCOUNT_HUB_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.discount_hub");

    uint256 public constant MAX_BASE_POINTS = 10000;
    uint256 public constant PRECISION = 1e36;
    uint256 public constant ONE_SNACK = 1e18;
    uint256 public constant CORRELATION_FACTOR = 1e24;

    struct Receiver {
        uint256 share;
        uint256 previousShare;
        address receiver;
        bool isBlocked;
    }

    struct StorageMappings {
        // who => snacks amount
        mapping(address => uint256) snacksDepositOf;
        // token => reward per token
        mapping(address => uint256) rewardPerTokenStored;
        // who => token => amount
        mapping(address => mapping(address => uint256)) depositeeRewardPerTokenPaid;
        mapping(address => mapping(address => uint256)) depositeeRewards;
        // token => amount of tokens came with notifyRewardAmount()
        mapping(address => uint256) acquiredTotalReward;
        // who => token => amount
        mapping(address => mapping(address => uint256)) unprocessedTokens;
    }

    struct StoragePrimitives {
        uint256 totalSnacksStaked;
        uint256 distributionPartitionBasePoints;
        address zoinks;
        address snacks;
        address snacksPool;
        address depositeeBlocklist;
        Receiver[] receivers;
        uint256 sumOfShares;
    }

    struct Storage {
        StorageMappings mappings;
        StoragePrimitives primitives;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = DISCOUNT_HUB_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}