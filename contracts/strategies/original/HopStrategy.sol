// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseStrategy} from "../../BaseStrategy.sol";

import "../../integrations/hop/IStakingRewards.sol";
import "../../integrations/hop/IRouter.sol";
import "../../utils/swaps/SwapHelperUser.sol";

contract HopStrategy is Initializable, BaseStrategy, SwapHelperUser {
    using SafeERC20 for IERC20;

    address internal constant HOP_ROUTER =
        0x10541b07d8Ad2647Dc6cD67abd4c03575dade261;
    address internal constant STAKING_REWARD =
        0xb0CabFE930642AD3E7DECdc741884d8C3F7EbC70;
    address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant LP = 0xB67c014FA700E69681a673876eb8BAFAA36BFf71;
    address internal constant HOP = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;
    
    address internal constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    uint256 internal constant MAX_BPS = 10000;

    uint256 public requestedQuoteHopToWant;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        address _sgBridge,
        address _sgRouter,
        uint256 _slippage,
        address _swapHelper
    ) external initializer {
        __BaseStrategy_init(
            _lzEndpoint,
            _strategist,
            _want,
            _vault,
            _vaultChainId,
            uint16(block.chainid),
            _sgBridge,
            _sgRouter,
            _slippage
        );
        swapHelper = IOraclizedSwapHelper(_swapHelper);
        IERC20(LP).safeApprove(STAKING_REWARD, type(uint256).max);
        IERC20(LP).safeApprove(HOP_ROUTER, type(uint256).max);
        IERC20(HOP).safeApprove(UNISWAP_V3_ROUTER, type(uint256).max);
        IERC20(HOP).safeApprove(_swapHelper, type(uint256).max);
        want.safeApprove(HOP_ROUTER, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "HopStrategy";
    }

    /// @dev MUST BE CALLED BEFORE estimatedTotalAssets() AND _withdrawSome()
    function updateHopToWantBuffer() external {
        _hopToWant(_rewardsEarned());
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            _lpToWant(_balanceOfStaked()) +
            balanceOfWant() +
            requestedQuoteHopToWant;
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        _claimAndSellRewards();
        uint256 unstakedBalance = balanceOfWant();

        uint256 excessWant;
        if (unstakedBalance > _debtOutstanding) {
            excessWant = unstakedBalance - _debtOutstanding;
        }
        if (excessWant > 0) {
            uint256[] memory liqAmounts = new uint256[](2);
            liqAmounts[0] = excessWant;
            liqAmounts[1] = 0;
            uint256 minAmount = 
                (
                    IRouter(HOP_ROUTER).calculateTokenAmount(
                        address(this),
                        liqAmounts,
                        true
                    ) * slippage
                ) / MAX_BPS;

            IRouter(HOP_ROUTER).addLiquidity(
                liqAmounts,
                minAmount,
                block.timestamp
            );
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
        _claimAndSellRewards();

        uint256 stakingAmount = balanceOfWant();
        IStakingRewards(STAKING_REWARD).withdraw(stakingAmount);
        IRouter(HOP_ROUTER).removeLiquidityOneToken(
            stakingAmount,
            0,
            0,
            block.timestamp
        );
        _amountFreed = want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        uint256 assets = _liquidateAllPositions();
        want.safeTransfer(_newStrategy, assets);
    }

    function _balanceOfStaked() internal view returns (uint256 amount) {
        amount = IStakingRewards(STAKING_REWARD).balanceOf(address(this));
    }

    function _rewardsEarned() internal view returns (uint256 amount) {
        amount = IStakingRewards(STAKING_REWARD).earned(address(this));
    }

    function _requestQuote(
        address tokenFrom,
        address tokenTo,
        uint256 amount
    ) internal returns (uint256) {
        swapHelper.requestQuoteAndFulfillOnOracleExpense(
            tokenFrom, tokenTo, amount
        );
        return requestedQuoteHopToWant;
    }

    function _lpToWant(
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        amountOut = IRouter(HOP_ROUTER).calculateRemoveLiquidityOneToken(
            address(this),
            amountIn,
            0
        );
    }

    function _hopToWant(
        uint256 amountIn
    ) internal {
        swapHelper.requestQuoteAndFulfillOnOracleExpense(
            HOP, address(want), amountIn
        );
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_amountNeeded == 0) {
            return;
        }
        uint256 hopRewardsInWantToken = requestedQuoteHopToWant;
        if (hopRewardsInWantToken >= _amountNeeded) {
            _claimAndSellRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                _balanceOfStaked(),
                _amountNeeded - hopRewardsInWantToken
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

        if (amountLpToWithdraw > balanceOfWant()) {
            amountLpToWithdraw = balanceOfWant();
        }

        IStakingRewards(STAKING_REWARD).withdraw(amountLpToWithdraw);
        uint256 minAmount = (_stakedAmount * slippage) / MAX_BPS;

        IRouter(HOP_ROUTER).removeLiquidityOneToken(
            amountLpToWithdraw,
            0,
            minAmount,
            block.timestamp
        );
    }

    function _sellHopForWant(uint256 amountToSell) internal {
        if (amountToSell == 0) {
            return;
        }
        
        uint8 adjustedTo1InchSlippage = uint8(
            (slippage * 100) / MAX_BPS
        );
        swapHelper.requestSwapAndFulfillOnOracleExpense(
            HOP, USDC, amountToSell, adjustedTo1InchSlippage
        );
    }

    function setSwapHelper(address __swapHelper) public onlyStrategistOrSelf {
        swapHelper = IOraclizedSwapHelper(__swapHelper);
    }

    function notifyCallback(
        address,
        address,
        uint256 amountOut,
        uint256
    ) external override onlySwapHelper {
        requestedQuoteHopToWant = amountOut;
    }
}
