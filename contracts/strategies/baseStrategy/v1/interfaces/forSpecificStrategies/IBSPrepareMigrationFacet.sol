// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IBSPrepareMigrationFacet {
    function prepareMigration(address newStrategy) external;
}