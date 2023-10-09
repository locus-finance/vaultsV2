// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../contracts/interfaces/IVault.sol";
import "../contracts/interfaces/IVaultV1.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Migration is Ownable, ReentrancyGuard {
    IVaultV1 public vaultV1;
    IVault public vaultV2;

    IERC20 public token;

    address public treasury;

    address[] public users;

    mapping(address user => uint256 balance) userToBalance;

    address[] public notWithdrawedUsers;

    constructor(
        address _vaultV1,
        address _vaultV2,
        address[] memory _users,
        address _treasury
    ) {
        vaultV1 = IVaultV1(_vaultV1);
        vaultV2 = IVault(_vaultV2);
        users = _users;
        token = vaultV1.token();
        treasury = _treasury;
        token.approve(address(vaultV2), type(uint256).max);
        token.approve(treasury, type(uint256).max);
    }

    function addUsers(address[] memory _newUsers) external onlyOwner {
        for (uint256 i = 0; i < _newUsers.length; i++) {
            users.push(_newUsers[i]);
        }
    }

    function withdraw() external nonReentrant {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 userBalance = IERC20(address(vaultV1)).balanceOf(users[i]);
            if (userBalance == 0) {
                continue;
            }
            if (
                IERC20(address(vaultV1)).allowance(users[i], address(this)) <
                userBalance
            ) {
                if (!checkUserExistance(users[i])) {
                    notWithdrawedUsers.push(users[i]);
                }
                continue;
            }
            IERC20(address(vaultV1)).transferFrom(
                users[i],
                address(this),
                userBalance
            );

            userToBalance[users[i]] += userBalance;
        }
        if (IERC20(address(vaultV1)).balanceOf(address(this)) > 0) {
            vaultV1.withdraw();
        }
    }

    function withdrawUsersWithDetectedError() external nonReentrant {
        for (uint256 i = 0; i < notWithdrawedUsers.length; i++) {
            if (notWithdrawedUsers[i] == address(0)) {
                continue;
            }
            uint256 userBalance = IERC20(address(vaultV1)).balanceOf(
                notWithdrawedUsers[i]
            );
            if (
                userBalance == 0 ||
                IERC20(address(vaultV1)).allowance(
                    notWithdrawedUsers[i],
                    address(this)
                ) <
                userBalance
            ) {
                continue;
            }
            IERC20(address(vaultV1)).transferFrom(
                notWithdrawedUsers[i],
                address(this),
                userBalance
            );

            userToBalance[notWithdrawedUsers[i]] += userBalance;

            notWithdrawedUsers[i] = address(0);
        }
        vaultV1.withdraw();
    }

    function deposit() external nonReentrant {
        //need to rethink, it is not safe to get all tokens on this account without ability to get this tokens back to users
        vaultV2.deposit(token.balanceOf(address(this)), address(this));
    }

    function emergencyExit() external onlyOwner {
        //emergency case
        token.transfer(treasury, token.balanceOf(address(this)));
        IERC20(address(vaultV2)).transfer(
            treasury,
            IERC20(address(vaultV2)).balanceOf(address(this))
        );
        IERC20(address(vaultV1)).transfer(
            treasury,
            IERC20(address(vaultV1)).balanceOf(address(this))
        );
    }

    function checkUserExistance(address _user) internal view returns (bool) {
        for (uint256 i = 0; i < notWithdrawedUsers.length; i++) {
            if (notWithdrawedUsers[i] == _user) {
                return true;
            }
        }
        return false;
    }
}
