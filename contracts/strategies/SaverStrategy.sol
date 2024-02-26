// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import {BaseStrategy} from "../BaseStrategy.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../integrations/beefy/IBeefyVault.sol";

contract SaverStrategy is Initializable, BaseStrategy, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    
    uint256 public constant DEFAULT_SLIPPAGE = 9_800;

    string private namePostfix;

    function initialize(
        address _lzEndpoint,
        address _strategist,
        address _harvester,
        IERC20 _want,
        address _vault,
        uint16 _strategyStargateChainId,
        uint16 _vaultStargateChainId,
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
            _vaultStargateChainId,
            _strategyStargateChainId,
            _sgBridge,
            _router,
            DEFAULT_SLIPPAGE
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner{}


    function migrateMoney(address token, address to) external onlyStrategist{
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }

    function name() external view override returns (string memory) {
        return string(abi.encodePacked("Saver"));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return 0;
            
    }

    function _adjustPosition(uint256 _debtOutstanding) internal override {
        
    }

    function _liquidatePosition(
        uint256 _amountNeeded
    ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        
    }

    function _liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        
    }

    function _prepareMigration(address _newStrategy) internal override {
        
    }
}
