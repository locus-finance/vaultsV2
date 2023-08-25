// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { BaseStrategy } from "../BaseStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../integrations/hop/IStakingRewards.sol";
import "../integrations/hop/IRouter.sol";

contract HopStrategy is Initializable, BaseStrategy {
    using SafeERC20 for IERC20;

    uint8 internal constant USDCindex = 0;
    uint8 internal constant USDCLPindex = 1;
    address internal constant HOP_ROUTER =
        0x10541b07d8Ad2647Dc6cD67abd4c03575dade261;
    address internal constant STAKING_REWARD =
        0xb0CabFE930642AD3E7DECdc741884d8C3F7EbC70;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant LP = 0xB67c014FA700E69681a673876eb8BAFAA36BFf71;
    address internal constant HOP = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;

    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant HOP_WETH_UNI_POOL =
        0x44ca2BE2Bd6a7203CCDBb63EED8382274f737A15;
    address internal constant WETH_USDC_UNI_POOL =
        0xC6962004f452bE9203591991D15f6b388e09E8D0;
    uint256 internal constant HOP_WETH_POOL_FEE = 3000;
    uint256 internal constant USDC_WETH_POOL_FEE = 500;
    address internal constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    uint32 internal constant TWAP_RANGE_SECS = 1800;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _router,
        uint256 _slippage
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            uint16(block.chainid),
            _sgBridge,
            _router,
            _slippage
        );

        IERC20(LP).safeApprove(STAKING_REWARD, type(uint256).max);
        IERC20(HOP).safeApprove(UNISWAP_V3_ROUTER, type(uint256).max);
        want.safeApprove(HOP_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "HopStrategy";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            LpToWant(balanceOfStaked()) +
            balanceOfUnstaked() +
            HopToWant(rewards());
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        uint256 unstakedBalance =balanceOfUnstaked(); 
        _claimAndSellRewards();
        if(unstakedBalance > _debtOutstanding ){
            //logic
        }
        if (unstakedBalance > 0) {
            uint256[] memory liqAmounts = new uint256[](2);
            liqAmounts[0] = unstakedBalance;
            liqAmounts[1] = 0;
            uint256 minAmount = IRouter(HOP_ROUTER).calculateTokenAmount(address(this),liqAmounts, true) * slippage / 10000;
            IRouter(HOP_ROUTER).addLiquidity(liqAmounts, minAmount, block.timestamp);
            uint256 lpBalance = IERC20(LP).balanceOf(address(this));
            IStakingRewards(STAKING_REWARD).stake(lpBalance);
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
        _exitPosition(balanceOfStaked());
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function balanceOfStaked() internal view returns (uint256 amount) {
        amount = IStakingRewards(STAKING_REWARD).balanceOf(address(this));
    }

    function balanceOfUnstaked() internal view returns (uint256 amount) {
        amount = want.balanceOf(address(this));
    }

    function rewards() internal view returns (uint256 amount) {
        amount = IStakingRewards(STAKING_REWARD).earned(address(this));
    }

    function smthToSmth(
        address pool,
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(pool, TWAP_RANGE_SECS);
        return
            OracleLibrary.getQuoteAtTick(
                meanTick,
                uint128(amount),
                tokenFrom,
                tokenTo
            );
    }

    function LpToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        amountOut = IRouter(HOP_ROUTER).calculateRemoveLiquidityOneToken(
            address(this),
            amountIn,
            0
        );
    }

    function HopToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        amountOut = smthToSmth(
            WETH_USDC_UNI_POOL,
            WETH,
            address(want),
            smthToSmth(HOP_WETH_UNI_POOL, HOP, WETH, amountIn)
        );
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (HopToWant(rewards()) >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                balanceOfStaked(),
                _amountNeeded - HopToWant(rewards())
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimAndSellRewards() internal {
        IStakingRewards(STAKING_REWARD).getReward();
        _sellHopForWant(IERC20(HOP).balanceOf(address(this)));
    }

    function _exitPosition(uint256 _stakedAmount) internal {
        _claimAndSellRewards();
        uint256[] memory amountsToWithdraw = new uint256[](2);
        amountsToWithdraw[0] = _stakedAmount;
        amountsToWithdraw[1] = 0;

        uint256 amountLpToWithdraw = IRouter(HOP_ROUTER).calculateTokenAmount(
            address(this),
            amountsToWithdraw,
            false
        );

        IStakingRewards(STAKING_REWARD).withdraw(amountLpToWithdraw);
        uint256 minAmount = (_stakedAmount * slippage) / 10000;

        IRouter(HOP_ROUTER).removeLiquidityOneToken(
            amountLpToWithdraw,
            0,
            minAmount,
            block.timestamp
        );
    }

    function _sellHopForWant(uint256 amountToSell) internal {
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            HOP,
            HOP_WETH_POOL_FEE,
            WETH,
            USDC_WETH_POOL_FEE,
            USDC
        );

        uint256 usdcExpected = HopToWant(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum = (usdcExpected * slippage) / 10000;
        ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    }
}
