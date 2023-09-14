// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPearlRouter, IPearlPair} from "../../../integrations/pearl/IPearlRouter.sol";
import {Utils} from "../../../utils/Utils.sol";

library PearlStrategyLib {
    address internal constant UNISWAP_V3_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant PEARL_ROUTER =
        0xcC25C0FD84737F44a7d38649b69491BBf0c7f083;
    address internal constant PEARL_USDR_LP =
        0xf68c20d6C50706f6C6bd8eE184382518C93B368c;
    
    function pearlToWant(
        uint256 _pearlAmount,
        address _pearlUsdrLp,
        address _pearl,
        address _usdr,
        uint8 _wantDecimals
    ) internal view returns (uint256) {
        uint256 usdrAmount = IPearlPair(_pearlUsdrLp).current(
            _pearl,
            _pearlAmount
        );
        return usdrToWant(usdrAmount, _usdr, _wantDecimals);
    }

    function usdrToWant(
        uint256 _usdrAmount,
        address _usdr,
        uint8 _wantDecimals
    ) internal view returns (uint256) {
        return
            Utils.scaleDecimals(
                _usdrAmount,
                IERC20Metadata(_usdr).decimals(),
                _wantDecimals
            );
    }
}
