// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../base/libraries/BaseLib.sol";
import "../base/libraries/InitializerLib.sol";
import "../base/libraries/PausabilityLib.sol";
import "../base/libraries/RolesManagementLib.sol";

import {ISgBridge} from "../../interfaces/ISgBridge.sol";
import {IStargateRouter} from "../../integrations/stargate/IStargate.sol";

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library BSLib {
    event StrategyMigrated(address newStrategy);
    event AdjustedPosition(uint256 debtOutstanding);

    bytes32 constant BASE_STRATEGY_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.base_strategy");

    uint256 public constant MAX_BPS = 10000;

    struct ReferenceTypes {
        mapping(uint256 => bool) withdrawnInEpoch;
    }

    struct Primitives {
        address strategist;
        IERC20 want;
        address vault;
        uint16 vaultChainId;
        uint16 currentChainId;
        uint8 wantDecimals;
        uint256 slippage;
        bool emergencyExit;
        ISgBridge sgBridge;
        IStargateRouter sgRouter;
        uint256 _signNonce;
    }

    struct Storage {
        ReferenceTypes rt; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE 
        Primitives p; // SUCH SHORT NAME TO DECREASE ANNOYING REPEATS IN CODE
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = BASE_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}