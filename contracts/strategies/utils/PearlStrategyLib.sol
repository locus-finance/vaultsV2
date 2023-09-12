// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Utils} from "../../utils/Utils.sol";
import {SwapHelperDTO} from "../../utils/SwapHelperUser.sol";
import {IPearlRouter, IPearlPair} from "../../integrations/pearl/IPearlRouter.sol";
import {IPearlGaugeV2} from "../../integrations/pearl/IPearlGaugeV2.sol";

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

    function usdrToWant(
        uint256 _usdrAmount,
        uint8 _wantDecimals
    ) public view returns (uint256) {
        return
            Utils.scaleDecimals(
                _usdrAmount,
                IERC20Metadata(USDR).decimals(),
                _wantDecimals
            );
    }

    function pearlToWant(
        uint256 _pearlAmount,
        uint8 _wantDecimals
    ) public view returns (uint256) {
        uint256 usdrAmount = IPearlPair(PEARL_USDR_LP).current(
            PEARL,
            _pearlAmount
        );
        return usdrToWant(usdrAmount, _wantDecimals);
    }

    function balanceOfPearlRewards() public view returns (uint256) {
        return IPearlGaugeV2(PEARL_GAUGE_V2).earned(address(this));
    }

    function balanceOfLpStaked() public view returns (uint256) {
        return IPearlGaugeV2(PEARL_GAUGE_V2).balanceOf(address(this));
    }

    function daiToWant(
        uint256 _daiAmount,
        uint8 _wantDecimals
    ) public view returns (uint256) {
        return
            Utils.scaleDecimals(
                _daiAmount,
                IERC20Metadata(DAI).decimals(),
                _wantDecimals
            );
    }

    function usdrLpToWant(
        uint256 _usdrLpAmount,
        address _want,
        uint8 _wantDecimals
    ) public view returns (uint256) {
        (uint256 amountA, uint256 amountB) = IPearlRouter(PEARL_ROUTER)
            .quoteRemoveLiquidity(_want, USDR, true, _usdrLpAmount);
        return amountA + usdrToWant(amountB, _wantDecimals);
    }

    function wantToUsdrLp(
        uint256 _wantAmount,
        address _want,
        uint8 _wantDecimals
    ) public view returns (uint256) {
        uint256 oneLp = usdrLpToWant(
            10 ** IERC20Metadata(USDC_USDR_LP).decimals(),
            _want,
            _wantDecimals
        );
        uint256 scaledWantAmount = Utils.scaleDecimals(
            _wantAmount,
            _wantDecimals,
            IERC20Metadata(USDC_USDR_LP).decimals()
        );
        uint256 scaledLp = Utils.scaleDecimals(
            oneLp,
            _wantDecimals,
            IERC20Metadata(USDC_USDR_LP).decimals()
        );

        return
            (scaledWantAmount *
                (10 ** IERC20Metadata(USDC_USDR_LP).decimals())) / scaledLp;
    }

    function _emergencySellUsdr(
        uint256 _usdrAmount,
        uint8 _wantDecimals,
        address _want,
        function(uint256) internal view returns (uint256) _withSlippage
    ) internal {
        uint256 wantAmountExpected = usdrToWant(_usdrAmount, _wantDecimals);
        IPearlRouter(PEARL_ROUTER).swapExactTokensForTokensSimple(
            _usdrAmount,
            _withSlippage(wantAmountExpected),
            USDR,
            _want,
            true,
            address(this),
            block.timestamp
        );
    }

    function _emergencySellPearl(
        uint256 _pearlAmount,
        uint8 _wantDecimals,
        address _want,
        function(uint256) internal view returns (uint256) _withSlippage
    ) internal {
        IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
        routes[0] = IPearlRouter.Route({from: PEARL, to: USDR, stable: false});
        routes[1] = IPearlRouter.Route({from: USDR, to: _want, stable: true});

        uint256 wantAmountExpected = pearlToWant(_pearlAmount, _wantDecimals);

        try
            IPearlRouter(PEARL_ROUTER).swapExactTokensForTokens(
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
        uint8 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function(address, address, uint256, bytes memory) internal _emitEvent,
        function(uint256) internal view returns (uint256) _withSlippage
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
            _emitEvent(
                PEARL,
                _want,
                _pearlAmount,
                abi.encodePacked(uint256(0))
            );
        } catch (bytes memory lowLevelErrorData) {
            _emergencySellPearl(
                _pearlAmount,
                _wantDecimals,
                _want,
                _withSlippage
            );
            _emitEvent(PEARL, _want, _pearlAmount, lowLevelErrorData);
        }
    }

    function exitPosition(
        uint256 _stakedLpTokens,
        address _want,
        uint8 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function(address, address, uint256, bytes memory) internal _emitEvent,
        function(uint256) internal view returns (uint256) _withSlippage
    ) internal {
        IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
        sellPearl(
            IERC20Metadata(PEARL).balanceOf(address(this)),
            _want,
            _wantDecimals,
            _swapHelperDTO,
            _emitEvent,
            _withSlippage
        );

        if (_stakedLpTokens == 0) {
            return;
        }

        IPearlGaugeV2(PEARL_GAUGE_V2).withdraw(_stakedLpTokens);
        (uint256 amountA, uint256 amountB) = IPearlRouter(PEARL_ROUTER)
            .quoteRemoveLiquidity(_want, USDR, true, _stakedLpTokens);
        IPearlRouter(PEARL_ROUTER).removeLiquidity(
            _want,
            USDR,
            true,
            _stakedLpTokens,
            _withSlippage(amountA),
            _withSlippage(amountB),
            address(this),
            block.timestamp
        );

        sellUsdr(
            IERC20Metadata(USDR).balanceOf(address(this)),
            _want,
            _wantDecimals,
            _swapHelperDTO,
            _emitEvent,
            _withSlippage
        );
    }

    function sellUsdr(
        uint256 _usdrAmount,
        address _want,
        uint8 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function(address, address, uint256, bytes memory) internal _emitEvent,
        function(uint256) internal view returns (uint256) _withSlippage
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
            _emergencySellUsdr(
                _usdrAmount,
                _wantDecimals,
                _want,
                _withSlippage
            );
            _emitEvent(USDR, _want, _usdrAmount, lowLevelErrorData);
        }
    }

    function withdrawSome(
        uint256 _amountNeeded,
        address _want,
        uint8 _wantDecimals,
        SwapHelperDTO storage _swapHelperDTO,
        function(address, address, uint256, bytes memory) internal _emitEvent,
        function(uint256) internal view returns (uint256) _withSlippage
    ) internal {
        if (_amountNeeded == 0) {
            return;
        }

        uint256 rewardsTotal = pearlToWant(
            balanceOfPearlRewards(),
            _wantDecimals
        );
        if (rewardsTotal >= _amountNeeded) {
            IPearlGaugeV2(PEARL_GAUGE_V2).getReward();
            sellPearl(
                IERC20Metadata(PEARL).balanceOf(address(this)),
                _want,
                _wantDecimals,
                _swapHelperDTO,
                _emitEvent,
                _withSlippage
            );
        } else {
            uint256 _wantToUsdrLp = wantToUsdrLp(
                _amountNeeded - rewardsTotal,
                _want,
                _wantDecimals
            );
            uint256 _balanceOfLpStaked = balanceOfLpStaked(); 
            uint256 lpTokensToWithdraw = _wantToUsdrLp > _balanceOfLpStaked ? _balanceOfLpStaked : _wantToUsdrLp;
            exitPosition(
                lpTokensToWithdraw,
                _want,
                _wantDecimals,
                _swapHelperDTO,
                _emitEvent,
                _withSlippage
            );
        }
    }
}
