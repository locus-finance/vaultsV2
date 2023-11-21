// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IPlainPool {
    /// @dev StableSwap.add_liquidity(_amounts: uint256[N_COINS], _min_mint_amount: uint256, _receiver: address = msg.sender) → uint256
    function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount, address _receiver) external returns (uint256);

    /// @dev StableSwap.remove_liquidity(_amount: uint256, _min_amounts: uint256[N_COINS]) → uint256[N_COINS]
    function remove_liquidity(uint256 _amount, uint256[] memory _min_amounts) external returns (uint256[] memory);

    /// @dev StableSwap.remove_liquidity_one_coin(_token_amount: uint256, i: int128, _min_amount: uint256) → uint256
    function remove_liquidity_one_coin(uint256 _amount, int128 i, uint256 _min_underlying_amount) external returns (uint256);

    /// @dev StableSwap.calc_withdraw_one_coin(_token_amount: uint256, i: int128) → uint256: view
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);

    /// @dev StableSwap.calc_token_amount(_amounts: uint256[N_COINS], _is_deposit: bool) → uint256: view
    function calc_token_amount(uint256[] memory _amounts, bool is_deposit) external view returns (uint256);

    /// @dev StableSwap.lp_token() → address: view
    function lp_token() external view returns (address);
}