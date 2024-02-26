// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDCMock {
    function mint(address _to, uint256 _amount) external returns (bool);

    function burn(uint256 _amount) external returns (bool);
}

contract StargateMock {
    event ExternalCallSuccess(
        address receiver,
        uint16 chainId,
        address token,
        uint256 amount
    );

    function bridge(
        address token,
        uint256 amount,
        uint16,
        address destinationAddress,
        address destinationToken,
        bytes calldata receiverPayload
    ) external payable {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IUSDCMock(destinationToken).mint(destinationAddress, amount);

        if (receiverPayload.length > 0) {
            externalCall(token, destinationAddress, amount, 0, receiverPayload);
        }
    }

    function externalCall(
        address token,
        address receiver,
        uint256 amount,
        uint16 chainId,
        bytes memory destPayload
    ) private {
        IERC20(token).transfer(receiver, amount);
        (bool success, bytes memory response) = receiver.call(destPayload);
        if (!success) {
            revert(_getRevertMsg(response));
        }
        emit ExternalCallSuccess(receiver, chainId, token, amount);
    }

    function _getRevertMsg(bytes memory _returnData)
        internal
        pure
        returns (string memory)
    {
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string));
    }
}
