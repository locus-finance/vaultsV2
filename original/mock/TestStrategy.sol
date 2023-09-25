// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// import {BaseStrategy} from "../strategies/original/BaseStrategy.sol";

// contract TestStrategy is Initializable, BaseStrategy {
//     function initialize(
//         address _lzEndpoint,
//         address _strategist,
//         IERC20 _want,
//         address _vault,
//         uint16 _vaultChainId,
//         uint16 _currentChainId,
//         address _sgBridge,
//         address _sgRouter,
//         uint256 _slippage
//     ) external initializer {
//         __BaseStrategy_init(
//             _lzEndpoint,
//             _strategist,
//             _want,
//             _vault,
//             _vaultChainId,
//             _currentChainId,
//             _sgBridge,
//             _sgRouter,
//             _slippage
//         );
//     }

//     function name() external pure override returns (string memory) {
//         return "TestStrategy";
//     }

//     function estimatedTotalAssets() public view override returns (uint256) {
//         return want.balanceOf(address(this));
//     }

//     function _adjustPosition(uint256 _debtOutstanding) internal override {
//         if (emergencyExit) {
//             return;
//         }

//         if (balanceOfWant() > _debtOutstanding) {
//             uint256 _excessWant = balanceOfWant() - _debtOutstanding;
//         }
//     }

//     function _liquidatePosition(
//         uint256 _amountNeeded
//     ) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
//         uint256 wantBal = want.balanceOf(address(this));
//         _liquidatedAmount = (wantBal > _amountNeeded) ? _amountNeeded : wantBal;
//         _loss = (_liquidatedAmount < _amountNeeded)
//             ? _amountNeeded - _liquidatedAmount
//             : 0;
//     }

//     function _liquidateAllPositions()
//         internal
//         override
//         returns (uint256 _amountFreed)
//     {
//         return want.balanceOf(address(this));
//     }

//     function _prepareMigration(address _newStrategy) internal override {}
// }
