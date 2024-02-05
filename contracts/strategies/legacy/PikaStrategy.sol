// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {BaseStrategy} from "../../BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../integrations/pika/IPikaPerpV4.sol";
import "../../integrations/pika/IVaultFeeReward.sol";
import "../../integrations/pika/IVaultTokenReward.sol";
import "../../integrations/pika/IVester.sol";

contract PikaStrategy is Initializable, BaseStrategy {
    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
        IERC20 _want,
        address _vault,
        uint16 _vaultChainId,
        uint16 _currentChainId,
        address _sgBridge,
        address _router,
        uint256 _slippage
    ) external initializer {
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
            _slippage
        );
    }

    using SafeERC20 for IERC20;

    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address internal constant PIKA = 0x9A601C5bb360811d96A23689066af316a30c3027;
    address internal constant ESPIKA =
        0x1508fbb7928aEdc86BEE68C91bC4aFcF493b0e78;

    //staking
    address internal constant PIKA_PERP_V4 =
        0x9b86B2Be8eDB2958089E522Fe0eB7dD5935975AB;
    //USDC
    address internal constant VAULT_FEE_REWARD =
        0x060c4Cb78f1a4508aD84CF2A65C6df9AFE3253Fe;
    //PIKA
    address internal constant VAULT_TOKEN_REWARD =
        0xa6caC988e3Bf78c54F3803B790485Eb8DF3fBAEb;

    address internal constant VESTER =
        0x21A4a5C00Ab2fD749ebEC8282456D93351459F2A;

    address internal constant UNI_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    uint32 internal constant TWAP_RANGE_SECS = 1800;

    address internal constant ETH_USDC_UNI_V3_POOL =
        0x85149247691df622eaF1a8Bd0CaFd40BC45154a9;

    address internal constant PIKA_ETH_UNI_V3_POOL =
        0x55bC964fE3B0C8cc2D4C63D65F1be7aef9BB1a3C;

    address internal constant UNISWAP_V3_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    uint256 internal constant PIKA_WETH_POOL_FEE = 10000;

    uint256 internal constant WETH_USDC_POOL_FEE = 10000;

    function name() external pure override returns (string memory) {
        return "Pika V4 Strategy";
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        _claimAndSellInstantRewards();
        //!Handle vester
        //!Do I need debt outstanding and what it is?
        if (balanceOfUnStaked() > 0) {
            IPikaPerpV4(PIKA_PERP_V4).stake(balanceOfUnStaked(), address(this));
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

    function _getUsdcRewards() internal view returns (uint256) {
        return
            IVaultFeeReward(VAULT_FEE_REWARD).getClaimableReward(address(this));
    }

    function _getPikaInVesting() internal view returns (uint256) {
        return pikaToWant(IVester(VESTER).claimableAll(address(this)));
    }

    function _getInstantRewards() internal view returns (uint256) {
        return _getUsdcRewards() + _getPikaInVesting();
    }

    function _withdrawSome(uint256 _amountNeeded) internal {
        if (_getUsdcRewards() >= _amountNeeded) {
            _claimUsdc();
        } else if (_getInstantRewards() >= _amountNeeded) {
            _claimAndSellInstantRewards();
        } else {
            uint256 _usdcToUnstake = Math.min(
                balanceOfStaked(),
                _amountNeeded - _getInstantRewards()
            );
            _exitPosition(_usdcToUnstake);
        }
    }

    function _claimUsdc() internal {
        IVaultFeeReward(VAULT_FEE_REWARD).claimReward(address(this));
    }

    function _claimAndSellInstantRewards() internal {
        _claimUsdc();
        IVester(VESTER).claimAll();
        _sellPikaForWant(IERC20(PIKA).balanceOf(address(this)));
    }

    function _sellPikaForWant(uint256 amountToSell) internal {
        ISwapRouter.ExactInputParams memory params;
        bytes memory swapPath = abi.encodePacked(
            PIKA,
            PIKA_WETH_POOL_FEE,
            WETH,
            WETH_USDC_POOL_FEE,
            USDC
        );

        uint256 usdcExpected = pikaToWant(amountToSell);
        params.path = swapPath;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = amountToSell;
        params.amountOutMinimum = (usdcExpected * slippage) / 10000;
        ISwapRouter(UNISWAP_V3_ROUTER).exactInput(params);
    }

    function _exitPosition(uint256 _stakedAmount) internal {
        _claimAndSellInstantRewards();
        IPikaPerpV4.Stake memory stake = IPikaPerpV4(PIKA_PERP_V4).getStake(
            address(this)
        );
        uint256 shares = (_stakedAmount * stake.shares) / stake.amount;
        if (_stakedAmount > 0) {
            IPikaPerpV4(PIKA_PERP_V4).redeem(
                address(this),
                shares,
                address(this)
            );
        }
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        _exitPosition(balanceOfStaked());
        return want.balanceOf(address(this));
    }

    function _prepareMigration(address _newStrategy) internal override {
        _exitPosition(balanceOfStaked());
        IVaultTokenReward(VAULT_TOKEN_REWARD).getReward();
        IVester(VESTER).deposit(IERC20(ESPIKA).balanceOf(address(this)));
        _claimAndSellInstantRewards();
        IERC20(PIKA).safeTransfer(
            _newStrategy,
            IERC20(PIKA).balanceOf(address(this))
        );
        want.safeTransfer(_newStrategy, balanceOfUnStaked());
    }

    function estimatedTotalAssets()
        public
        view
        override
        returns (uint256 amount)
    {
        amount = balanceOfStaked() + balanceOfUnStaked() + getAllRewards();
    }

    function balanceOfStaked() internal view returns (uint256 balance) {
        IPikaPerpV4.Stake memory stake = IPikaPerpV4(PIKA_PERP_V4).getStake(
            address(this)
        );
        balance = stake.amount;
    }

    function balanceOfUnStaked() internal view returns (uint256 balance) {
        balance = IERC20(USDC).balanceOf(address(this));
    }

    function getAllRewards() internal view returns (uint256 balance) {
        //usdc
        balance = IVaultFeeReward(VAULT_FEE_REWARD).getClaimableReward(
            address(this)
        );
        //pika in vault (fee included + full time deposit)
        balance += pikaToWant(
            IVaultTokenReward(VAULT_TOKEN_REWARD).earned(address(this))
        );
        //pika in vesting
        balance += pikaToWant(IVester(VESTER).claimableAll(address(this)));
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

    function pikaToWant(uint256 amount) internal view returns (uint256 result) {
        result = smthToSmth(
            ETH_USDC_UNI_V3_POOL,
            WETH,
            address(want),
            smthToSmth(PIKA_ETH_UNI_V3_POOL, PIKA, WETH, amount)
        );
    }
}
