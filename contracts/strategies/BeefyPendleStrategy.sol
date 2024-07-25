// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "../integrations/cryptoalgebra/IGetGlobalStateFromPool.sol";
import "./libraries/BeefyPendleStrategyLib.sol";

import "hardhat/console.sol";

contract BeefyPendleStrategy is Initializable, BaseStrategy, UUPSUpgradeable {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    // EmptySwap means no swap aggregator is involved
    SwapData public emptySwap;
    // EmptyLimit means no limit order is involved
    LimitOrderData public emptyLimit;
    // DefaultApprox means no off-chain preparation is involved, more gas consuming (~ 180k gas)
    ApproxParams public defaultApprox;
    uint32 public durationForPendleOracle;

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
            BeefyPendleStrategyLib.DEFAULT_SLIPPAGE
        );
        want.approve(
            address(BeefyPendleStrategyLib.CAMELOT_SWAP_ROUTER),
            type(uint256).max
        );
        BeefyPendleStrategyLib.USDe.approve(
            address(BeefyPendleStrategyLib.CAMELOT_SWAP_ROUTER),
            type(uint256).max
        );

        BeefyPendleStrategyLib.USDe.approve(
            address(BeefyPendleStrategyLib.PENDLE_ROUTER),
            type(uint256).max
        );
        BeefyPendleStrategyLib.PENDLE_MARKET.approve(
            address(BeefyPendleStrategyLib.PENDLE_ROUTER),
            type(uint256).max
        );

        BeefyPendleStrategyLib.PENDLE_MARKET.approve(
            address(BeefyPendleStrategyLib.PENDLE_MARKET),
            type(uint256).max
        );

        BeefyPendleStrategyLib.PENDLE_MARKET.approve(
            address(BeefyPendleStrategyLib.BEEFY_VAULT),
            type(uint256).max
        );
        BeefyPendleStrategyLib.BEEFY_VAULT.approve(
            address(BeefyPendleStrategyLib.BEEFY_VAULT),
            type(uint256).max
        );

        durationForPendleOracle = 1800;
        defaultApprox = ApproxParams(0, type(uint256).max, 0, 256, 1e14);
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
        return BeefyPendleStrategyLib.USDe.balanceOf(address(this));
    }

    function balanceOfPendleLp() external view returns (uint256) {
        return BeefyPendleStrategyLib.PENDLE_MARKET.balanceOf(address(this));
    }

    function balanceOfBeefyShares() public view returns (uint256) {
        return BeefyPendleStrategyLib.BEEFY_VAULT.balanceOf(address(this));
    }

    function previewUsdeToPendleLpConversion(
        uint256 usdeIn
    ) public view returns (uint256 pendleLpOut) {
        return
            BeefyPendleStrategyLib.previewUsdeToPendleLpConversion(
                usdeIn,
                durationForPendleOracle
            );
    }

    function previewPendleLpToUsdeConversion(
        uint256 pendleLpIn
    ) public view returns (uint256 usdeOut) {
        return
            BeefyPendleStrategyLib.previewPendleLpToUsdeConversion(
                pendleLpIn,
                durationForPendleOracle
            );
    }

    function previewFromBeefySharesToPendleLpConversion(
        uint256 shares
    ) public view returns (uint256 pendleLpOut) {
        return
            BeefyPendleStrategyLib.previewFromBeefySharesToPendleLpConversion(
                shares
            );
    }

    function previewFromPendleLpToBeefySharesConversion(
        uint256 pendleLpIn
    ) public view returns (uint256 shares) {
        return
            BeefyPendleStrategyLib.previewFromPendleLpToBeefySharesConversion(
                pendleLpIn
            );
    }

    function getQuoteOnCamelot(
        address[] memory tokensChain,
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        amountOut = amountIn;
        uint256 qNotationScale = 1 << 96;
        for (uint256 i = 1; i <= tokensChain.length - 1; i++) {
            address firstToken = tokensChain[i - 1];
            address secondToken = tokensChain[i];
            console.log("---", i);
            console.log(IERC20Metadata(firstToken).symbol(), " - ", IERC20Metadata(secondToken).symbol());
            console.log("amountOut at start: ", amountOut);
            IGetGlobalStateFromPool pool = IGetGlobalStateFromPool(BeefyPendleStrategyLib.CAMELOT_FACTORY.poolByPair(firstToken, secondToken));
            console.log("pool address: ", address(pool));
            IGetGlobalStateFromPool.GlobalState memory poolGlobalState = pool.globalState();

            if (i == 1) {
                amountOut = amountOut.toUint160() << 96; // safe cast to Q64.96
            }
            console.log("amount out converted: ", amountOut);
            console.log("sqrtPrice: ", poolGlobalState.price);
            
            if (pool.token0() == firstToken && pool.token1() == secondToken) {
                amountOut = (amountOut * poolGlobalState.price) >> 96; // multiply amountOut and price (that are both in Q64.96)
            } else {
                amountOut = (amountOut * qNotationScale) / poolGlobalState.price; // divide amountOut by price (that are both in Q64.96)
            }
            
            console.log("amount out with price: ", amountOut);
            console.log("***", i);
        }
        // amountOut = amountOut >> 96; // cast back to uint256
        console.log('finish: ', amountOut);
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        address[] memory tokensChain = new address[](3);
        tokensChain[0] = address(BeefyPendleStrategyLib.USDe);
        tokensChain[1] = address(BeefyPendleStrategyLib.USDC_NON_BRIDGED);
        tokensChain[2] = address(want);
        return
            balanceOfWant() +
            getQuoteOnCamelot(
                tokensChain,
                previewPendleLpToUsdeConversion(
                    previewFromBeefySharesToPendleLpConversion(
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
        uint256 pendleLpMinted = BeefyPendleStrategyLib.depositUsdeIntoPendle(
            usdeSwapped,
            defaultApprox,
            emptyLimit,
            emptySwap
        );
        beefySharesMinted = BeefyPendleStrategyLib.mintBeefySharesFromPendleLp(
            pendleLpMinted
        );
    }

    function _convertBeefySharesToWant(
        uint256 amountBeefyShares
    ) internal returns (uint256 wantTokensGathered) {
        if (amountBeefyShares == 0) return 0;
        uint256 pendleLpWithdrawn = BeefyPendleStrategyLib
            .burnBeefySharesToPendleLp(amountBeefyShares);
        uint256 usdeWithdrawnFromPendle = BeefyPendleStrategyLib
            .withdrawUsdeFromPendle(pendleLpWithdrawn, emptyLimit, emptySwap);
        wantTokensGathered = _swapUsdeToWant(usdeWithdrawnFromPendle);
    }

    function _swapWantToUsde(
        uint256 wantAmount
    ) internal returns (uint256 usdeOut) {
        address[] memory tokensChain = new address[](3);
        tokensChain[0] = address(want);
        tokensChain[1] = address(BeefyPendleStrategyLib.USDC_NON_BRIDGED);
        tokensChain[2] = address(BeefyPendleStrategyLib.USDe);

        usdeOut = BeefyPendleStrategyLib.swapOnCamelot(
            tokensChain,
            wantAmount
        );
        emit BeefyPendleStrategyLib.WantToUsdeOperation(usdeOut, false);
    }

    function _swapUsdeToWant(
        uint256 usdeAmount
    ) internal returns (uint256 wantOut) {
        address[] memory tokensChain = new address[](3);
        tokensChain[0] = address(BeefyPendleStrategyLib.USDe);
        tokensChain[1] = address(BeefyPendleStrategyLib.USDC_NON_BRIDGED);
        tokensChain[2] = address(want);
        wantOut = BeefyPendleStrategyLib.swapOnCamelot(
            tokensChain,
            usdeAmount
        );
        emit BeefyPendleStrategyLib.WantToUsdeOperation(wantOut, true);
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }

        address[] memory tokensChain = new address[](3);
        tokensChain[0] = address(want);
        tokensChain[1] = address(BeefyPendleStrategyLib.USDC_NON_BRIDGED);
        tokensChain[2] = address(BeefyPendleStrategyLib.USDe);
        uint256 sharesToBurn = Math.min(
            balanceOfBeefyShares(),
            previewFromPendleLpToBeefySharesConversion(
                previewUsdeToPendleLpConversion(
                    getQuoteOnCamelot(
                        tokensChain,
                        _amountNeeded
                    )
                )
            )
        );
        _convertBeefySharesToWant(sharesToBurn);
    }
}
