// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "../interfaces/IDepositary.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/ITokenPostProcessor.sol";
import "./base/DHBaseFacet.sol";

contract DepositaryFacet is IDepositary, DHBaseFacet {
    using SafeERC20 for IERC20;

    function deposit(
        IERC20 token,
        address depositee, // if depositing for custodial clients - just use address(this)
        uint256 amount
    ) external override delegatedOnly {
        if (depositee != address(this)) {
            RolesManagementLib.enforceRole(
                depositee,
                RolesManagementLib.DEPOSITEE_ROLE
            );
        }
        if (amount == 0) {
            revert BaseLib.MustBeGTZero();
        }
        _checkIfIsInBlocklist(depositee);
        RolesManagementLib.enforceSenderRole(RolesManagementLib.AUTHORITY_ROLE);
        RolesManagementLib.enforceRole(
            address(token),
            RolesManagementLib.ALLOWED_TOKEN_ROLE
        );

        IStaking(address(this)).updateReward(depositee);

        if (depositee == address(this)) {
            token.safeTransferFrom(msg.sender, address(this), amount);
        } else {
            token.safeTransferFrom(depositee, address(this), amount);
        }

        uint256 amountInSnacks = ITokenPostProcessor(address(this)).postProcessDeposit(
            depositee,
            address(token),
            amount
        );
        emit Deposit(address(token), depositee, amountInSnacks);
    }

    function transformDeposit(
        address to,
        uint256 amount
    ) external override delegatedOnly {
        _checkIfIsInBlocklist(to);
        RolesManagementLib.enforceSenderRole(RolesManagementLib.AUTHORITY_ROLE);
        DHLib.StorageMappings storage s = DHLib.get().mappings;
        s.snacksDepositOf[address(this)] -= amount;
        s.snacksDepositOf[to] += amount;
        IStaking(address(this)).updateReward(to);
        IStaking(address(this)).updateReward(address(this));
        emit Transform(to, amount);
    }

    function withdraw(
        IERC20 token,
        uint256 amount, // IN SNACKS
        address from, // if withdrawing for custodial client then must be set to - address(this)
        address recipient
    ) external override delegatedOnly {
        _checkIfIsInBlocklist(recipient);
        _checkIfIsInBlocklist(from);
        RolesManagementLib.enforceSenderRole(RolesManagementLib.AUTHORITY_ROLE);
        RolesManagementLib.enforceRole(
            address(token),
            RolesManagementLib.ALLOWED_TOKEN_ROLE
        );
        uint256 amountInToken = ITokenPostProcessor(address(this)).postProcessWithdraw(
            from,
            address(token),
            amount
        );
        token.safeTransfer(recipient, amountInToken);
        emit Withdraw(address(token), recipient, amountInToken);
    }
}
