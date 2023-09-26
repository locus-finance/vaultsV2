// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library PSLib {
    bytes32 constant PEARL_STRATEGY_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage.pearl_strategy");

    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    address internal constant USDR = 0x40379a439D4F6795B6fc9aa5687dB461677A2dBa;
    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address internal constant PEARL =
        0x7238390d5f6F64e67c3211C343A410E2A3DEc142;

    address internal constant USDR_EXCHANGE =
        0x195F7B233947d51F4C3b756ad41a5Ddb34cEBCe0;

    address internal constant USDC_USDR_LP =
        0xD17cb0f162f133e339C0BbFc18c36c357E681D6b;
    address internal constant PEARL_GAUGE_V2 =
        0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876;

    address internal constant UNISWAP_V3_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant PEARL_ROUTER =
        0xcC25C0FD84737F44a7d38649b69491BBf0c7f083;
    address internal constant PEARL_USDR_LP =
        0xf68c20d6C50706f6C6bd8eE184382518C93B368c;

    struct Storage {
        uint8 adjustedTo1InchSlippage;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = PEARL_STRATEGY_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
