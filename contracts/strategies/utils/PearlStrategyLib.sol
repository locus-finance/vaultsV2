// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @notice The contract is built to avoid max size per contract file constraint.
library PearlStrategyLib {
    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    address internal constant USDR = 0x40379a439D4F6795B6fc9aa5687dB461677A2dBa;
    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address internal constant PEARL =
        0x7238390d5f6F64e67c3211C343A410E2A3DEc142;

    address internal constant DAI_USDC_V3_POOL =
        0x5645dCB64c059aa11212707fbf4E7F984440a8Cf;
    uint24 internal constant DAI_USDC_UNI_V3_FEE = 100;

    address internal constant UNISWAP_V3_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant USDR_EXCHANGE =
        0x195F7B233947d51F4C3b756ad41a5Ddb34cEBCe0;
    address internal constant PEARL_ROUTER =
        0xcC25C0FD84737F44a7d38649b69491BBf0c7f083;

    address internal constant PEARL_USDR_LP =
        0xf68c20d6C50706f6C6bd8eE184382518C93B368c;
    address internal constant USDC_USDR_LP =
        0xD17cb0f162f133e339C0BbFc18c36c357E681D6b;
    address internal constant PEARL_GAUGE_V2 =
        0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876;
}