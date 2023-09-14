// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
* @title Interface that can be used to interact with the Pausable contract.
*/
interface IPausable {
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}
