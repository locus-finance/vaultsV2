// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import "@pendle/core-v2/contracts/oracles/PendleLpOracleLib.sol";
import "@cryptoalgebra/v1.9-periphery/contracts/interfaces/ISwapRouter.sol";
import "@cryptoalgebra/v1.9-core/contracts/interfaces/IAlgebraFactory.sol";

import "../../integrations/beefy/IBeefyVault.sol";

library BeefyPendleStrategyLib {
    event WantToUsdeOperation(
        uint256 indexed amountSwapped,
        bool indexed isTokensSwappedToWant
    );
    event PendleLpTokensOperation(
        uint256 indexed amountMintedOrBurned,
        bool indexed isMinted
    );
    event BeefyVaultSharesOperation(
        uint256 indexed amountMintedOrBurned,
        bool indexed isMinted
    );

    IBeefyVault public constant BEEFY_VAULT =
        IBeefyVault(0x631d5C4bA949418D7D856Acc4e33EC2FFF96b590);
    ISwapRouter public constant CAMELOT_SWAP_ROUTER =
        ISwapRouter(0x1F721E2E82F6676FCE4eA07A5958cF098D339e18);
    IAlgebraFactory public constant CAMELOT_FACTORY = IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B);

    IPAllActionV3 public constant PENDLE_ROUTER =
        IPAllActionV3(0x888888888889758F76e7103c6CbF23ABbF58F946);
    IPMarket public constant PENDLE_MARKET =
        IPMarket(0x2Dfaf9a5E4F293BceedE49f2dBa29aACDD88E0C4);

    IERC20Metadata public constant USDe =
        IERC20Metadata(0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34);
    IERC20Metadata public constant USDC_NON_BRIDGED =
        IERC20Metadata(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    uint256 public constant PRECISION = 1 ether;
    uint256 public constant DEFAULT_SLIPPAGE = 9_500;

    function depositUsdeIntoPendle(
        uint256 usdeAmount,
        ApproxParams memory defaultApprox,
        LimitOrderData memory emptyLimit,
        SwapData memory emptySwap
    ) external returns (uint256 netLpOut) {
        (netLpOut, , ) = PENDLE_ROUTER.addLiquiditySingleToken(
            address(this),
            address(PENDLE_MARKET),
            0,
            defaultApprox,
            _createTokenInputStruct(address(USDe), usdeAmount, emptySwap),
            emptyLimit
        );
        emit PendleLpTokensOperation(netLpOut, true);
    }

    function withdrawUsdeFromPendle(
        uint256 pendleLpAmount,
        LimitOrderData memory emptyLimit,
        SwapData memory emptySwap
    ) external returns (uint256 netUsdeOut) {
        (netUsdeOut, , ) = PENDLE_ROUTER.removeLiquiditySingleToken(
            address(this),
            address(PENDLE_MARKET),
            pendleLpAmount,
            _createTokenOutputStruct(address(USDe), 0, emptySwap),
            emptyLimit
        );
        emit PendleLpTokensOperation(netUsdeOut, false);
    }

    function burnBeefySharesToPendleLp(
        uint256 sharesAmount
    ) external returns (uint256 sharesBurned) {
        uint256 oldBeefySharesBalance = BEEFY_VAULT.balanceOf(address(this));
        BEEFY_VAULT.withdraw(sharesAmount);
        sharesBurned =
            oldBeefySharesBalance -
            BEEFY_VAULT.balanceOf(address(this));
        emit BeefyVaultSharesOperation(sharesBurned, false);
    }

    function mintBeefySharesFromPendleLp(
        uint256 pendleLpAmount
    ) external returns (uint256 sharesMinted) {
        uint256 oldBeefySharesBalance = BEEFY_VAULT.balanceOf(address(this));
        BEEFY_VAULT.deposit(pendleLpAmount);
        sharesMinted =
            BEEFY_VAULT.balanceOf(address(this)) -
            oldBeefySharesBalance;
        emit BeefyVaultSharesOperation(sharesMinted, false);
    }

    /// @notice create a simple TokenInput struct without using any aggregators. For more info please refer to
    /// IPAllActionTypeV3.sol
    function _createTokenInputStruct(
        address tokenIn,
        uint256 netTokenIn,
        SwapData memory emptySwap
    ) internal pure returns (TokenInput memory) {
        return
            TokenInput({
                tokenIn: tokenIn,
                netTokenIn: netTokenIn,
                tokenMintSy: tokenIn,
                pendleSwap: address(0),
                swapData: emptySwap
            });
    }

    /// @notice create a simple TokenOutput struct without using any aggregators. For more info please refer to
    /// IPAllActionTypeV3.sol
    function _createTokenOutputStruct(
        address tokenOut,
        uint256 minTokenOut,
        SwapData memory emptySwap
    ) internal pure returns (TokenOutput memory) {
        return
            TokenOutput({
                tokenOut: tokenOut,
                minTokenOut: minTokenOut,
                tokenRedeemSy: tokenOut,
                pendleSwap: address(0),
                swapData: emptySwap
            });
    }

    function swapOnCamelot(
        address[] memory tokensChain,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        bytes memory path = abi.encodePacked(tokensChain[0]);
        for (uint256 i = 1; i <= tokensChain.length - 1; i++) {
            path = abi.encodePacked(path, tokensChain[i]);
        }
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });
        amountOut = CAMELOT_SWAP_ROUTER.exactInput(params);
    }

    function previewUsdeToPendleLpConversion(
        uint256 usdeIn,
        uint32 durationForPendleOracle
    ) external view returns (uint256 pendleLpOut) {
        uint256 lpToAssetRate = PendleLpOracleLib.getLpToAssetRate(
            PENDLE_MARKET,
            durationForPendleOracle
        );
        pendleLpOut = (PRECISION * usdeIn) / lpToAssetRate;
    }

    function previewPendleLpToUsdeConversion(
        uint256 pendleLpIn,
        uint32 durationForPendleOracle
    ) external view returns (uint256 usdeOut) {
        uint256 lpToAssetRate = PendleLpOracleLib.getLpToAssetRate(
            PENDLE_MARKET,
            durationForPendleOracle
        );
        usdeOut = (pendleLpIn * lpToAssetRate) / PRECISION;
    }

    function previewFromBeefySharesToPendleLpConversion(
        uint256 shares
    ) external view returns (uint256 pendleLpOut) {
        pendleLpOut = (shares * BEEFY_VAULT.getPricePerFullShare()) / PRECISION;
    }

    function previewFromPendleLpToBeefySharesConversion(
        uint256 pendleLpIn
    ) external view returns (uint256 shares) {
        shares = (pendleLpIn * PRECISION) / BEEFY_VAULT.getPricePerFullShare();
    }
}
