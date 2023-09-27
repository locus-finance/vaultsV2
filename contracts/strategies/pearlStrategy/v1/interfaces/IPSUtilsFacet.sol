// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../../baseStrategy/v1/interfaces/IBSQuoteNotifiableFacet.sol";

interface IPSUtilsFacet is IBSQuoteNotifiableFacet {
    function pearlToWant(uint256 _pearlAmount) external view returns (uint256);

    function usdrToWant(uint256 _usdrAmount) external view returns (uint256);

    function daiToWant(uint256 _daiAmount) external view returns (uint256);

    function usdrLpToWant(uint256 _usdrLpAmount) external view returns (uint256);

    function wantToUsdrLp(uint256 _wantAmount) external view returns (uint256);

    function sellUsdr(uint256 _usdrAmount) external;

    function sellPearl(uint256 _pearlAmount) external;
}
