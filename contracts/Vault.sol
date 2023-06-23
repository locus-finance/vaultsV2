// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";
import {StrategyParams, IVault} from "./interfaces/IVault.sol";

contract Vault is
    Ownable,
    ERC20,
    IVault,
    IStrategyMessages,
    IStargateReceiver,
    NonblockingLzApp
{
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address _governance,
        address _lzEndpoint,
        IERC20 _token,
        address _sgBridge,
        address _router
    ) NonblockingLzApp(_lzEndpoint) ERC20("Omnichain Vault", "OMV") {
        governance = _governance;
        token = _token;
        sgBridge = ISgBridge(_sgBridge);
        router = IStargateRouter(_router);
    }

    uint256 public immutable VALID_REPORT_THRESHOLD = 6 hours;

    address public override governance;
    IERC20 public override token;

    ISgBridge public sgBridge;
    IStargateRouter public router;

    uint256 public totalDebt;
    mapping(uint16 => mapping(address => StrategyParams)) public strategies;

    mapping(uint16 => EnumerableSet.AddressSet) internal _strategiesByChainId;
    EnumerableSet.UintSet internal _supportedChainIds;

    modifier onlyAuthorized() {
        require(
            msg.sender == governance || msg.sender == owner(),
            "Vault::Unauthorized"
        );
        _;
    }

    function totalAssets() public view override returns (uint256, uint256) {
        uint256 freeFunds = token.balanceOf(address(this));
        uint256 investedFunds = 0;
        uint256 lastReport = type(uint256).max;

        for (uint256 i = 0; i < _supportedChainIds.length(); i++) {
            uint16 chainId = uint16(_supportedChainIds.at(i));
            EnumerableSet.AddressSet
                storage strategiesByChainId = _strategiesByChainId[chainId];

            for (uint256 j = 0; j < strategiesByChainId.length(); j++) {
                address strategy = strategiesByChainId.at(j);
                StrategyParams storage params = strategies[chainId][strategy];
                if (params.debtRatio > 0) {
                    investedFunds += params.lastReportedTotalAssets;
                    lastReport = Math.min(lastReport, params.lastReport);
                }
            }
        }

        return (freeFunds + investedFunds, lastReport);
    }

    function addStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee
    ) external override onlyOwner {
        require(
            strategies[_chainId][_strategy].activation == 0,
            "Vault::StrategyAlreadyAdded"
        );

        strategies[_chainId][_strategy] = StrategyParams({
            performanceFee: _performanceFee,
            activation: block.timestamp,
            debtRatio: _debtRatio,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0,
            lastReport: 0,
            lastReportedTotalAssets: 0
        });

        _strategiesByChainId[_chainId].add(_strategy);
        _supportedChainIds.add(uint256(_chainId));
    }

    function handleDeposits() external override onlyAuthorized {}

    function handleWithdrawals() external override onlyAuthorized {}

    function pricePerShare() external view override returns (uint256) {
        return _shareValue(10 ** decimals());
    }

    function viewStrategy(
        uint16 _chainId,
        address _strategy
    ) external view override returns (StrategyParams memory) {
        return strategies[_chainId][_strategy];
    }

    function revokeStrategy(
        uint16 _chainId,
        address strategy
    ) external override onlyAuthorized {}

    function _shareValue(uint256 shares) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return shares;
        }
        (uint256 assets, ) = totalAssets();
        return (shares * assets) / totalSupply();
    }

    function _isLastReportValid() internal view returns (bool) {
        (, uint256 lastReport) = totalAssets();
        return
            lastReport > 0 &&
            block.timestamp - lastReport < VALID_REPORT_THRESHOLD;
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal override {}

    function sgReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint,
        address _token,
        uint256 _amountLD,
        bytes memory _payload
    ) external override {
        require(msg.sender == address(router), "Vault::RouterOnly");

        address srcAddress = abi.decode(_srcAddress, (address));
        require(
            strategies[_srcChainId][srcAddress].activation > 0,
            "Vault::IncorrectSender"
        );

        MessageType messageType = abi.decode(_payload, (MessageType));
        if (messageType == MessageType.WithdrawSomeResponse) {
            (, WithdrawSomeResponse memory message) = abi.decode(
                _payload,
                (uint256, WithdrawSomeResponse)
            );
        }

        emit SgReceived(_token, _amountLD, srcAddress);
    }

    receive() external payable {}
}
