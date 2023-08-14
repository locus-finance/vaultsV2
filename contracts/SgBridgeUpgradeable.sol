// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";

contract SgBridgeUpgradeable is Initializable, OwnableUpgradeable {
    event Bridge(uint16 destChainId, uint256 amount);

    error UnknownDestChainId(uint16 destChainId);

    using SafeERC20 for IERC20;

    IStargateRouter public router;

    uint256 public bridgeSlippage;
    uint256 public dstGasForCall;
    uint256 public currentChainId;
    uint256 public srcPoolId;

    mapping(uint16 => uint256) public destPoolIds;

    uint256[10] private __gap;

    function __SgBridge_init(
        address _router,
        uint256 _currentChainId,
        uint256 _srcPoolId
    ) internal onlyInitializing {
        __Ownable_init();

        router = IStargateRouter(_router);
        currentChainId = _currentChainId;
        srcPoolId = _srcPoolId;

        bridgeSlippage = 9_900;
        dstGasForCall = 500_000;
    }

    function setRouter(address _router) external onlyOwner {
        router = IStargateRouter(_router);
    }

    function setBridgeSlippage(uint256 _bridgeSlippage) external onlyOwner {
        bridgeSlippage = _bridgeSlippage;
    }

    function setDstGasForCall(uint256 _dstGasForCall) external onlyOwner {
        dstGasForCall = _dstGasForCall;
    }

    function setCurrentChainId(uint16 _currentChainId) external onlyOwner {
        currentChainId = _currentChainId;
    }

    function setDestPoolId(
        uint16 _destChainId,
        uint256 _destPoolId
    ) external onlyOwner {
        destPoolIds[_destChainId] = _destPoolId;
    }

    function _bridge(
        address _token,
        uint256 _amount,
        uint16 _destChainId,
        address _destinationAddress,
        bytes memory _message
    ) internal {
        if (destPoolIds[_destChainId] == 0) {
            revert UnknownDestChainId(_destChainId);
        }

        if (_destChainId == currentChainId) {
            IERC20(_token).safeTransferFrom(
                address(this),
                _destinationAddress,
                _amount
            );
            IStargateReceiver(_destinationAddress).sgReceive(
                _destChainId,
                abi.encodePacked(address(this)),
                0,
                _token,
                _amount,
                _message
            );
            return;
        }

        _bridgeInternal(
            _amount,
            srcPoolId,
            _destChainId,
            destPoolIds[_destChainId],
            _destinationAddress,
            _message
        );
    }

    function _bridgeInternal(
        uint256 _amount,
        uint256 _srcPoolId,
        uint16 _destChainId,
        uint256 _destinationPoolId,
        address _destinationContract,
        bytes memory _payload
    ) internal {
        uint256 withSlippage = (_amount * bridgeSlippage) / 10_000;

        (uint256 fee, ) = router.quoteLayerZeroFee(
            _destChainId,
            /* _functionType */ 1,
            abi.encodePacked(_destinationContract),
            _payload,
            _getLzParams()
        );

        router.swap{value: fee}(
            _destChainId,
            _srcPoolId,
            _destinationPoolId,
            payable(address(this)),
            _amount,
            withSlippage,
            _getLzParams(),
            abi.encodePacked(_destinationContract),
            _payload
        );

        emit Bridge(_destChainId, _amount);
    }

    function _getLzParams()
        internal
        view
        returns (IStargateRouter.LzTxObj memory)
    {
        return
            IStargateRouter.LzTxObj({
                dstGasForCall: dstGasForCall,
                dstNativeAmount: 0,
                dstNativeAddr: abi.encode(address(this))
            });
    }
}
