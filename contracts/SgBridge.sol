// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStargateRouter} from "./interfaces/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";

contract SgBridge is Ownable, ISgBridge {
    IStargateRouter public router;

    uint256 public slippage = 9_900;
    uint256 public dstGasForCall = 500_000;

    constructor(IStargateRouter _router) {
        router = _router;
    }

    function setSlippage(uint256 _slippage) external override onlyOwner {
        slippage = _slippage;
    }

    function _bridgeInternal(
        uint256 fee,
        uint256 amount,
        uint256 srcPoolId,
        uint16 destChainId,
        uint256 destinationPoolId,
        address destinationAddress,
        address destinationToken,
        address destinationContract
    ) internal {
        IStargateRouter.LzTxObj memory lzParams = IStargateRouter.LzTxObj({
            dstGasForCall: dstGasForCall,
            dstNativeAmount: 0,
            dstNativeAddr: abi.encode(address(this))
        });

        bytes memory payload = abi.encode(destinationAddress, destinationToken);

        router.swap{value: fee}(
            destChainId,
            srcPoolId,
            destinationPoolId,
            payable(msg.sender),
            amount,
            0,
            lzParams,
            abi.encodePacked(destinationContract),
            payload
        );

        emit Bridge(destChainId, amount);
    }
}
