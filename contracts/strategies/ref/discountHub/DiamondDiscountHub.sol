// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../../interfaces/IPausable.sol";
import "./interfaces/IDepositary.sol";
import "../base/interfaces/IRolesManagement.sol";
import "./interfaces/IDistributionChain.sol";
import "./interfaces/IDistributionChainLoupe.sol";
import "./interfaces/IInitializer.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IStats.sol";
import "./interfaces/ITokenPostProcessor.sol";

// IMPORTANT: all of the collective diamond interfaces MUST be prefixed with Diamond word.
interface DiamondDiscountHub is
    IPausable,
    IDepositary,
    IRolesManagement,
    IDistributionChain,
    IDistributionChainLoupe,
    IInitializer,
    IRewardDistributor,
    IStaking,
    IStats,
    ITokenPostProcessor
{}
