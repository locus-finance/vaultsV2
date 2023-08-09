// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {BaseStrategy} from "../BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../integrations/pika/IPikaPerpV4.sol";
import "../integrations/pika/IVaultFeeReward.sol";
import "../integrations/pika/IVaultTokenReward.sol";

contract PikaStrategy is Initializable, BaseStrategy {
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
            _sgBridge,
            _router,
            _slippage
        );
    }

    //staking
    address internal constant PIKA_PERP_V4 =
        0x9b86B2Be8eDB2958089E522Fe0eB7dD5935975AB;
    address internal constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    //USDC
    address internal constant VAULT_FEE_REWARD =
        0x060c4Cb78f1a4508aD84CF2A65C6df9AFE3253Fe;
    //PIKA
    address internal constant VAULT_TOKEN_REWARD =
        0xa6caC988e3Bf78c54F3803B790485Eb8DF3fBAEb;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;

    address internal constant UNI_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    uint32 internal constant TWAP_RANGE_SECS = 1800;

    address internal constant ETH_USDC_UNI_V3_POOL =
        0x9e0b4A404Bfb889f8cA2D4679db3Ceaf75F24b43;

    function name() external view override returns (string memory) {
        return "Pika V4 Strategy";
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        //getAll rewards
        //sell all
        //check if want balance gt debtOutstanding swap all
        //add liquidity
        //depositAll
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        //check if this contract has enough balance(gt _amount needed)
        //if yes return(_amountNeeded, 0)
        //withdraw from farm
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {}

    function _prepareMigration(address _newStrategy) internal override {
        //withdraw all from farm
        //transfer all tokens to new strategy address
    }

    function estimatedTotalAssets()
        public
        view
        override
        returns (uint256 amount)
    {
        // getRewards + balance of the same tokens on this address
        amount = balanceOfWant();
        // amount +=
        return 0;
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

    //!need converter from pika to USDC
    function getAllRewards() internal view returns (uint256 balance) {
        //usdc
        balance = IVaultFeeReward(VAULT_FEE_REWARD).getClaimableReward(
            address(this)
        );
        //pika convert
        balance += IVaultTokenReward(VAULT_TOKEN_REWARD).earned(address(this));
    }

    // function smthToWant(
    //     uint256 amount,
    //     address token,
    //     uint24 fee
    // ) public view returns (uint256) {
    //     address pool =
    //     (int24 meanTick, ) = OracleLibrary.consult(
    //         ETH_USDC_UNI_V3_POOL,
    //         TWAP_RANGE_SECS
    //     );
    //     return
    //         OracleLibrary.getQuoteAtTick(
    //             meanTick,
    //             uint128(amount),
    //             WETH,
    //             address(want)
    //         );
    // }

    function smthToEth(uint256 amount) public view returns (uint256) {}

    function ethToWantMyFunc(uint128 amount) public view returns (uint256) {
        (int24 meanTick, ) = OracleLibrary.consult(
            ETH_USDC_UNI_V3_POOL,
            TWAP_RANGE_SECS
        );
        // return
        //     OracleLibrary.getQuoteAtTick(
        //         meanTick,
        //         uint128(amount),
        //         WETH,
        //         address(want)
        //     );
        return amount;
    }

    function getPool(
        address token1,
        address token2,
        uint24 fee
    ) external view returns (address) {
        return
            IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984)
                .getPool(token1, token2, fee);
    }

    function getFactoryOwner() external view returns (address) {
        return
            IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984)
                .owner();
    }

    function check(uint256 amount) public view returns (uint256) {
        return amount;
    }
}
