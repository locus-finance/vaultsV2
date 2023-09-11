// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;


import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Utils} from "../../utils/Utils.sol";
import {SwapHelperDTO} from "../../utils/SwapHelperUser.sol";
import {IPearlRouter, IPearlPair} from "../../integrations/pearl/IPearlRouter.sol";

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

    function usdrToWant(uint256 _usdrAmount, uint256 _wantDecimals) internal view returns (uint256) {
        return
            Utils.scaleDecimals(
                _usdrAmount,
                IERC20Metadata(USDR).decimals(),
                uint8(_wantDecimals)
            );
    }

    function _emergencySellUsdr(
        uint256 _usdrAmount, 
        uint256 _wantDecimals,
        address _want,
        function (uint256) internal view returns(uint256) _withSlippage
    ) internal {
        uint256 wantAmountExpected = usdrToWant(_usdrAmount, _wantDecimals);
        IPearlRouter(PEARL_ROUTER)
            .swapExactTokensForTokensSimple(
                _usdrAmount,
                _withSlippage(wantAmountExpected),
                USDR,
                _want,
                true,
                address(this),
                block.timestamp
            );
    }

    function sellUsdr(
        uint256 _usdrAmount,
        address _want,
        uint256 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function (address, address, uint256, bytes memory) internal _emitEvent,
        function (uint256) internal view returns (uint256) _withSlippage
    ) internal {
        if (_usdrAmount == 0) {
            return;
        }
        try
            _swapHelperDTO.swapHelper.requestSwapAndFulfillOnOracleExpense(
                USDR,
                _want,
                _usdrAmount,
                uint8((DEFAULT_SLIPPAGE * 100) / 10000) // converting into 1inch scaled slippage percent (10000 BPS -> 100%)
            )
        {
            _emitEvent(USDR, _want, _usdrAmount, abi.encodePacked(uint256(0)));
        } catch (bytes memory lowLevelErrorData) {
            _emergencySellUsdr(_usdrAmount, _wantDecimals, _want, _withSlippage);
            _emitEvent(USDR, _want, _usdrAmount, lowLevelErrorData);
        }
    }

    function pearlToWant(uint256 _pearlAmount, uint256 _wantDecimals) internal view returns (uint256) {
        uint256 usdrAmount = IPearlPair(PEARL_USDR_LP).current(
            PEARL,
            _pearlAmount
        );
        return usdrToWant(usdrAmount, _wantDecimals);
    }

    function _emergencySellPearl(
        uint256 _pearlAmount, 
        uint256 _wantDecimals, 
        address _want,
        function (uint256) internal view returns(uint256) _withSlippage
    ) internal {
        IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
        routes[0] = IPearlRouter.Route({
            from: PEARL,
            to: USDR,
            stable: false
        });
        routes[1] = IPearlRouter.Route({
            from: USDR,
            to: _want,
            stable: true
        });

        uint256 wantAmountExpected = pearlToWant(_pearlAmount, _wantDecimals);

        try
            IPearlRouter(PearlStrategyLib.PEARL_ROUTER)
                .swapExactTokensForTokens(
                    _pearlAmount,
                    _withSlippage(wantAmountExpected),
                    routes,
                    address(this),
                    block.timestamp
                )
        returns (uint256[] memory) {} catch {}
    }

    function sellPearl(
        uint256 _pearlAmount,
        address _want,
        uint256 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function (address, address, uint256, bytes memory) internal _emitEvent,
        function (uint256) internal view returns(uint256) _withSlippage
    ) internal {
        if (_pearlAmount == 0) {
            return;
        }
        try
            _swapHelperDTO.swapHelper.requestSwapAndFulfillOnOracleExpense(
                PEARL,
                _want,
                _pearlAmount,
                uint8((DEFAULT_SLIPPAGE * 100) / 10000) // converting into 1inch scaled slippage percent (10000 BPS -> 100%)
            )
        {
            _emitEvent(PEARL, _want, _pearlAmount, abi.encodePacked(uint256(0)));
        } catch (bytes memory lowLevelErrorData) {
            _emergencySellPearl(_pearlAmount, _wantDecimals, _want, _withSlippage);
            _emitEvent(PEARL, _want, _pearlAmount, lowLevelErrorData);
        }
    }
}
