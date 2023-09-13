// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import {IV3SwapRouter} from "../../integrations/uniswap/IV3SwapRouter.sol";
import {IPearlRouter, IPearlPair} from "../../integrations/pearl/IPearlRouter.sol";

import "../../strategies/utils/PearlStrategyLib.sol";
import "../../interfaces/ISwapHelper.sol";

contract EmergencyUniswapV3SwapHelper is ISwapHelper {
    using SafeERC20 for IERC20;

    error OnlyOraclizedSwapHelper();
    error CannotFindPoolAddressFor(address src, address dst);

    modifier onlyOraclizedSwapHelper() {
        if (msg.sender != oraclizedSwapHelper) {
            revert OnlyOraclizedSwapHelper();
        }
        _;
    }

    address internal constant HOP_WETH_UNI_POOL =
        0x44ca2BE2Bd6a7203CCDBb63EED8382274f737A15;
    uint256 internal constant HOP_WETH_POOL_FEE = 3000;

    address internal constant WETH_USDC_UNI_POOL =
        0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
    uint256 internal constant USDC_WETH_POOL_FEE = 500;
    
    address internal constant ETH_USDC_UNI_V3_POOL =
        0xC6962004f452bE9203591991D15f6b388e09E8D0;

    address internal constant DAI_USDC_V3_POOL =
        0x5645dCB64c059aa11212707fbf4E7F984440a8Cf;
    uint24 internal constant DAI_USDC_UNI_V3_FEE = 100;
    
    uint32 internal constant TWAP_RANGE_SECS = 1800;

    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ONE_INCH_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address internal constant USDR = 0x40379a439D4F6795B6fc9aa5687dB461677A2dBa;
    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address internal constant PEARL =
        0x7238390d5f6F64e67c3211C343A410E2A3DEc142;
    address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant HOP = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;

    uint8 internal constant USDC_DECIMALS = 6;

    address public oraclizedSwapHelper;
    uint8 public fixedSlippage;

    constructor(address _oraclizedSwapHelper, uint8 _slippage) {
        oraclizedSwapHelper = _oraclizedSwapHelper;
        fixedSlippage = _slippage;
    }

    function _requestQuoteFromUniswapV3Oracle(
        address src,
        address dst,
        uint256 amount,
        address poolForQuote
    ) internal view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(
            poolForQuote,
            TWAP_RANGE_SECS
        );
        return
            OracleLibrary.getQuoteAtTick(
                meanTick,
                uint128(amount),
                src,
                dst
            );
    }

    // solhint-disable-next-line
    function requestQuote(
        address src,
        address dst,
        uint256 amount
    ) external override onlyOraclizedSwapHelper returns (uint256 amountOut) {
        if (src == HOP && dst == WETH || dst == HOP && src == WETH) {
            amountOut = _requestQuoteFromUniswapV3Oracle(
                src, dst, amount, HOP_WETH_UNI_POOL
            );
        } else if (src == WETH && dst == USDC || dst == WETH && src == USDC) {
            amountOut = _requestQuoteFromUniswapV3Oracle(
                src, dst, amount, WETH_USDC_UNI_POOL
            );
        } else if (src == ONE_INCH_ETH_ADDRESS && dst == USDC 
                || dst == ONE_INCH_ETH_ADDRESS && src == USDC) {
            amountOut = _requestQuoteFromUniswapV3Oracle(
                src, dst, amount, ETH_USDC_UNI_V3_POOL
            );
        } else if (src == DAI && dst == USDC || dst == DAI && src == USDC) {
            amountOut = _requestQuoteFromUniswapV3Oracle(
                src, dst, amount, DAI_USDC_V3_POOL
            );
        } else {
            revert CannotFindPoolAddressFor(src, dst);   
        }
    }

    /////

    // uint256 scaledHalfWant = Utils.scaleDecimals(
    //     halfWant,
    //     wantDecimals,
    //     ERC20(DAI).decimals()
    // );
    // IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
    //     .ExactInputParams({
    //         path: abi.encodePacked(
    //             address(want),
    //             DAI_USDC_UNI_V3_FEE,
    //             DAI
    //         ),
    //         recipient: address(this),
    //         amountIn: halfWant,
    //         amountOutMinimum: _withSlippage(scaledHalfWant)
    //     });
    // IV3SwapRouter(UNISWAP_V3_ROUTER).exactInput(params);

    // IPearlRouter(PEARL_ROUTER).swapExactTokensForTokensSimple(
    //     _usdrAmount,
    //     _withSlippage(wantAmountExpected),
    //     USDR,
    //     address(want),
    //     true,
    //     address(this),
    //     block.timestamp
    // );

    function _quoteHopToUSDC(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        amountOut = _requestQuoteFromUniswapV3Oracle(
            WETH,
            USDC,
            _requestQuoteFromUniswapV3Oracle(HOP, WETH, amountIn, HOP_WETH_UNI_POOL),
            WETH_USDC_UNI_POOL
        );
    }

    function _withSlippage(uint256 _amount) internal view returns (uint256) {
        return (_amount * fixedSlippage) / 10_000;
    }

    function requestSwap(
        address src,
        address dst,
        uint256 amount,
        uint8 slippage
    ) external payable override onlyOraclizedSwapHelper {
        if (src == HOP && dst == USDC) {
            ISwapRouter.ExactInputParams memory params;
            bytes memory swapPath = abi.encodePacked(
                HOP,
                uint24(HOP_WETH_POOL_FEE),
                WETH,
                uint24(USDC_WETH_POOL_FEE),
                USDC
            );
            uint256 usdcExpected = _quoteHopToUSDC(amount);
            params.path = swapPath;
            params.recipient = address(this);
            params.deadline = block.timestamp;
            params.amountIn = amount;
            params.amountOutMinimum =
                (usdcExpected * slippage) /
                10000;
            ISwapRouter(PearlStrategyLib.UNISWAP_V3_ROUTER).exactInput(params);
        } else if (src == PEARL && dst == USDC) {
            // // IPearlRouter.Route[] memory routes = new IPearlRouter.Route[](2);
            // // routes[0] = IPearlRouter.Route({from: PEARL, to: USDR, stable: false});
            // // routes[1] = IPearlRouter.Route({
            // //     from: USDR,
            // //     to: USDC,
            // //     stable: true
            // // });

            // // uint256 wantAmountExpected = PearlStrategyLib.pearlToWant(
            // //     amount,
            // //     PEARL_USDR_LP,
            // //     PEARL,
            // //     USDR,

            // // );

            // try
            //     IPearlRouter(PearlStrategyLib.PEARL_ROUTER).swapExactTokensForTokens(
            //         amount,
            //         _withSlippage(wantAmountExpected),
            //         routes,
            //         address(this),
            //         block.timestamp
            //     )
            // returns (uint256[] memory) {} catch {}
        }
        
    }
}
