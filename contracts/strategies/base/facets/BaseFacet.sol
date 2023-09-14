// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";

import "../libraries/InitializerLib.sol";
import "../libraries/BaseLib.sol";

abstract contract BaseFacet is UsingDiamondOwner {
    modifier delegatedOnly {
        InitializerLib.enforceDelegatedOnly();
        _;
    }

    modifier internalOnly {
        BaseLib.enforceInternal();
        _;
    }
}