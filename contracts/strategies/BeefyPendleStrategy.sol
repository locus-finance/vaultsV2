// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import "@pendle/core-v2/contracts/oracles/PendleLpOracleLib.sol";
import "@cryptoalgebra/v1.9-periphery/contracts/interfaces/ISwapRouter.sol";
import "@cryptoalgebra/v1.9-periphery/contracts/interfaces/IQuoter.sol";

import "../integrations/beefy/IBeefyVault.sol";

contract BeefyPendleStrategy is Initializable, BaseStrategy, UUPSUpgradeable {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using PendleLpOracleLib for IPMarket;

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
    IQuoter public constant CAMELOT_QUOTER =
        IQuoter(0x0Fc73040b26E9bC8514fA028D998E73A254Fa76E);

    IPAllActionV3 public constant PENDLE_ROUTER =
        IPAllActionV3(0x888888888889758F76e7103c6CbF23ABbF58F946);
    IPMarket public constant PENDLE_MARKET =
        IPMarket(0x2Dfaf9a5E4F293BceedE49f2dBa29aACDD88E0C4);

    IERC20Metadata public constant USDe =
        IERC20Metadata(0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34);

    uint256 public constant PRECISION = 1 ether;
    uint256 public constant DEFAULT_SLIPPAGE = 9_500;

    // EmptySwap means no swap aggregator is involved
    SwapData public emptySwap;
    // EmptyLimit means no limit order is involved
    LimitOrderData public emptyLimit;
    // DefaultApprox means no off-chain preparation is involved, more gas consuming (~ 180k gas)
    ApproxParams public defaultApprox =
        ApproxParams(0, type(uint256).max, 0, 256, 1e14);

    uint32 public durationForPendleOracle = 1800;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _router
    ) external initializer {
        __UUPSUpgradeable_init();
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _harvester,
            _want,
            _vault,
            _vaultChainId,
            _currentChainId,
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );
        want.approve(address(CAMELOT_SWAP_ROUTER), type(uint256).max);
        USDe.approve(address(CAMELOT_SWAP_ROUTER), type(uint256).max);
        USDe.approve(address(PENDLE_ROUTER), type(uint256).max);
        PENDLE_MARKET.approve(address(PENDLE_ROUTER), type(uint256).max);
    }

    function setDurationForPendleOracle(uint32 _duration) external onlyOwner {
        durationForPendleOracle = _duration;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function name() external pure override returns (string memory) {
        return "USDC -> USDe -> Pendle LP -> Beefy Vault Strategy";
    }

    function balanceOfUsde() external view returns (uint256) {
        return USDe.balanceOf(address(this));
    }

    function balanceOfPendleLp() external view returns (uint256) {
        return PENDLE_MARKET.balanceOf(address(this));
    }

    function balanceOfBeefyShares() public view returns (uint256) {
        return BEEFY_VAULT.balanceOf(address(this));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            balanceOfWant() +
            _getQuoteOnCamelot(
                address(USDe),
                address(want),
                _previewPendleLpToUsdeConversion(
                    _previewFromBeefySharesToPendleLpConversion(
                        balanceOfBeefyShares()
                    )
                )
            );
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        uint256 unstakedBalance = balanceOfWant();

        uint256 excessWant;
        if (unstakedBalance > _debtOutstanding) {
            excessWant = unstakedBalance - _debtOutstanding;
        }
        if (excessWant > 0) {
            _convertWantToBeefyShares(excessWant);
        }
    }

    function _swapWantToUsde(
        uint256 wantAmount
    ) internal returns (uint256 usdeOut) {
        usdeOut = _swapOnCamelot(address(want), address(USDe), wantAmount);
        emit WantToUsdeOperation(usdeOut, false);
    }

    function _swapUsdeToWant(
        uint256 usdeAmount
    ) internal returns (uint256 wantOut) {
        wantOut = _swapOnCamelot(address(USDe), address(want), usdeAmount);
        emit WantToUsdeOperation(wantOut, true);
    }

    function _depositUsdeIntoPendle(
        uint256 usdeAmount
    ) internal returns (uint256 netLpOut) {
        (netLpOut, , ) = PENDLE_ROUTER.addLiquiditySingleToken(
            address(this),
            address(PENDLE_MARKET),
            0,
            defaultApprox,
            _createTokenInputStruct(address(USDe), usdeAmount),
            emptyLimit
        );
        emit PendleLpTokensOperation(netLpOut, true);
    }

    function _withdrawUsdeFromPendle(
        uint256 pendleLpAmount
    ) internal returns (uint256 netUsdeOut) {
        (netUsdeOut, , ) = PENDLE_ROUTER.removeLiquiditySingleToken(
            address(this),
            address(PENDLE_MARKET),
            pendleLpAmount,
            _createTokenOutputStruct(address(USDe), 0),
            emptyLimit
        );
        emit PendleLpTokensOperation(netUsdeOut, false);
    }

    function _burnBeefySharesToPendleLp(
        uint256 sharesAmount
    ) internal returns (uint256 sharesBurned) {
        uint256 oldBeefySharesBalance = balanceOfBeefyShares();
        BEEFY_VAULT.withdraw(sharesAmount);
        sharesBurned = oldBeefySharesBalance - balanceOfBeefyShares();
        emit BeefyVaultSharesOperation(sharesBurned, false);
    }

    function _mintBeefySharesFromPendleLp(
        uint256 pendleLpAmount
    ) internal returns (uint256 sharesMinted) {
        uint256 oldBeefySharesBalance = balanceOfBeefyShares();
        BEEFY_VAULT.deposit(pendleLpAmount);
        sharesMinted = balanceOfBeefyShares() - oldBeefySharesBalance;
        emit BeefyVaultSharesOperation(sharesMinted, false);
    }

    /// @notice create a simple TokenInput struct without using any aggregators. For more info please refer to
    /// IPAllActionTypeV3.sol
    function _createTokenInputStruct(
        address tokenIn,
        uint256 netTokenIn
    ) internal view returns (TokenInput memory) {
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
        uint256 minTokenOut
    ) internal view returns (TokenOutput memory) {
        return
            TokenOutput({
                tokenOut: tokenOut,
                minTokenOut: minTokenOut,
                tokenRedeemSy: tokenOut,
                pendleSwap: address(0),
                swapData: emptySwap
            });
    }

    function _swapOnCamelot(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            });
        amountOut = CAMELOT_SWAP_ROUTER.exactInputSingle(params);
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBal = want.balanceOf(address(this));
        if (_wantBal >= _amountNeeded) {
            return (_amountNeeded, 0);
        }

        _withdrawSome(_amountNeeded - _wantBal);
        _wantBal = want.balanceOf(address(this));

        if (_amountNeeded > _wantBal) {
            _liquidatedAmount = _wantBal;
            _loss = _amountNeeded - _wantBal;
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        _convertBeefySharesToWant(balanceOfBeefyShares());
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function _convertWantToBeefyShares(
        uint256 amountWant
    ) internal returns (uint256 beefySharesMinted) {
        if (amountWant == 0) return 0;
        uint256 usdeSwapped = _swapWantToUsde(amountWant);
        uint256 pendleLpMinted = _depositUsdeIntoPendle(usdeSwapped);
        beefySharesMinted = _mintBeefySharesFromPendleLp(pendleLpMinted);
    }

    function _convertBeefySharesToWant(
        uint256 amountBeefyShares
    ) internal returns (uint256 wantTokensGathered) {
        if (amountBeefyShares == 0) return 0;
        uint256 pendleLpWithdrawn = _burnBeefySharesToPendleLp(
            amountBeefyShares
        );
        uint256 usdeWithdrawnFromPendle = _withdrawUsdeFromPendle(
            pendleLpWithdrawn
        );
        wantTokensGathered = _swapUsdeToWant(usdeWithdrawnFromPendle);
    }

    function _previewUsdeToPendleLpConversion(
        uint256 usdeIn
    ) internal view returns (uint256 pendleLpOut) {
        uint256 lpToAssetRate = PENDLE_MARKET.getLpToAssetRate(durationForPendleOracle);
        pendleLpOut = (PRECISION * usdeIn) / lpToAssetRate;
    }

    function _previewPendleLpToUsdeConversion(
        uint256 pendleLpIn
    ) internal view returns (uint256 usdeOut) {
        uint256 lpToAssetRate = PENDLE_MARKET.getLpToAssetRate(durationForPendleOracle);
        usdeOut = (pendleLpIn * lpToAssetRate) / PRECISION;
    }

    function _previewFromBeefySharesToPendleLpConversion(
        uint256 shares
    ) internal view returns (uint256 pendleLpOut) {
        pendleLpOut = (shares * BEEFY_VAULT.getPricePerFullShare()) / PRECISION;
    }

    function _previewFromPendleLpToBeefySharesConversion(
        uint256 pendleLpIn
    ) internal view returns (uint256 shares) {
        shares = (pendleLpIn * PRECISION) / BEEFY_VAULT.getPricePerFullShare();
    }

    function _getQuoteOnCamelot(
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal view returns (uint256 amountOut) {
        bytes memory quoteCalldata = abi.encodeWithSelector(
            CAMELOT_QUOTER.quoteExactInputSingle.selector,
            tokenFrom,
            tokenTo,
            amount,
            0
        );
        bytes memory quoteResult = Address.functionStaticCall(
            address(CAMELOT_QUOTER),
            quoteCalldata
        );
        (amountOut, ) = abi.decode(quoteResult, (uint256, uint16));
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        uint256 sharesToBurn = Math.min(balanceOfBeefyShares(), _amountNeeded);
        _convertBeefySharesToWant(sharesToBurn);
    }
}
