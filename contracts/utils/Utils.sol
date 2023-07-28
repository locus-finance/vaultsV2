// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library Utils {
    function scaleDecimals(
        uint _amount,
        ERC20 _fromToken,
        ERC20 _toToken
    ) internal view returns (uint _scaled) {
        uint8 decFrom = _fromToken.decimals();
        uint8 decTo = _toToken.decimals();

        return scaleDecimals(_amount, decFrom, decTo);
    }

    function scaleDecimals(
        uint _amount,
        uint8 _decimalsFrom,
        uint8 _decimalsTo
    ) internal pure returns (uint) {
        if (_decimalsTo > _decimalsFrom) {
            return _amount * (10 ** (_decimalsTo - _decimalsFrom));
        } else {
            return _amount / (10 ** (_decimalsFrom - _decimalsTo));
        }
    }
}
