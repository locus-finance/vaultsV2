// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IStrategyMessages} from "../../../interfaces/IStrategyMessages.sol";

import "./interfaces/IBSUtilsFacet.sol";
import "./interfaces/IBSLiquidatePositionFacet.sol";
import "./interfaces/IBSHarvestFacet.sol";
import "./interfaces/IBSStargateFacet.sol";
import "./interfaces/IBSStatsFacet.sol";
import "./interfaces/IBSLayerZeroFacet.sol";
import "../../diamondBase/facets/BaseFacet.sol";
import "../../diamondBase/libraries/RolesManagementLib.sol";
import "../BSLib.sol";

contract BSHarvestFacet is BaseFacet, IBSHarvestFacet {
    function harvest(
        uint256 _totalDebt,
        uint256 _debtOutstanding,
        uint256 _creditAvailable,
        uint256 _debtRatio,
        bytes memory _signature
    ) external override delegatedOnly {
        RolesManagementLib.enforceSenderRole(RolesManagementLib.STRATEGIST_ROLE);
        
        BSLib.Primitives storage p = BSLib.get().p;

        IBSUtilsFacet(address(this)).verifySignature(_signature);

        uint256 profit = 0;
        uint256 loss = 0;
        uint256 debtPayment = 0;

        if (p.emergencyExit) {
            if (_debtRatio > 0) {
                revert DebtRatioNotZero();
            }

            uint256 amountFreed = IBSLiquidatePositionFacet(address(this))
                .liquidateAllPositions();
            
            if (amountFreed < _debtOutstanding) {
                loss = _debtOutstanding - amountFreed;
            } else if (amountFreed > _debtOutstanding) {
                profit = amountFreed - _debtOutstanding;
            }
            debtPayment = _debtOutstanding - loss;
        } else {
            (profit, loss, debtPayment) = _prepareReturn(
                _totalDebt,
                _debtOutstanding
            );
        }

        uint256 fundsAvailable = profit + debtPayment;
        uint256 giveToStrategy = 0;
        uint256 requestFromStrategy = 0;

        if (fundsAvailable < _creditAvailable) {
            giveToStrategy = _creditAvailable - fundsAvailable;
            requestFromStrategy = 0;
        } else {
            giveToStrategy = 0;
            requestFromStrategy = fundsAvailable - _creditAvailable;
        }

        IStrategyMessages.StrategyReport memory report = IStrategyMessages.StrategyReport({
            strategy: address(this),
            timestamp: block.timestamp,
            profit: profit,
            loss: loss,
            debtPayment: debtPayment,
            giveToStrategy: giveToStrategy,
            requestFromStrategy: requestFromStrategy,
            creditAvailable: _creditAvailable,
            totalAssets: IBSStatsFacet(address(this)).estimatedTotalAssets() - requestFromStrategy,
            nonce: p.signNonce++,
            signature: _signature
        });

        if (requestFromStrategy > 0) {
            IBSStargateFacet(address(this)).bridge(
                requestFromStrategy,
                p.vaultChainId,
                p.vault,
                abi.encode(IStrategyMessages.MessageType.StrategyReport, report)
            );
        } else {
            IBSLayerZeroFacet(address(this)).sendMessageToVault(abi.encode(IStrategyMessages.MessageType.StrategyReport, report));
        }

        emit StrategyReported(
            report.profit,
            report.loss,
            report.debtPayment,
            report.giveToStrategy,
            report.requestFromStrategy,
            report.creditAvailable,
            report.totalAssets
        );
    }

    function _prepareReturn(
        uint256 _totalDebt,
        uint256 _debtOutstanding
    ) internal returns (uint256 profit, uint256 loss, uint256 debtPayment) {
        uint256 totalAssets = IBSStatsFacet(address(this)).estimatedTotalAssets();

        if (totalAssets >= _totalDebt) {
            profit = totalAssets - _totalDebt;
            loss = 0;
        } else {
            profit = 0;
            loss = _totalDebt - totalAssets;
        }

        IBSLiquidatePositionFacet(address(this)).liquidatePosition(_debtOutstanding + profit);

        uint256 liquidWant = BSLib.get().p.want.balanceOf(address(this));
        if (liquidWant <= profit) {
            profit = liquidWant;
            debtPayment = 0;
        } else {
            debtPayment = Math.min(liquidWant - profit, _debtOutstanding);
        }
    }
}