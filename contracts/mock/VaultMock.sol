pragma solidity ^0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultMock is ERC20 {
    address public token;

    constructor(address _token) ERC20("MockVault", "MV") {
        token = _token;
    }

    function deposit(
        uint256 _amount,
        address _recipient
    ) external returns (uint256) {
        _mint(_recipient, _amount);
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        return 0;
    }
}
