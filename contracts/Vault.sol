// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BytesLib, NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";
import {StrategyParams, DepositRequest, WithdrawRequest, DepositEpoch, WithdrawEpoch, IVault} from "./interfaces/IVault.sol";

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
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

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

    uint256 public constant VALID_REPORT_THRESHOLD = 6 hours;
    uint256 public constant MAX_BPS = 10_000;

    address public override governance;
    IERC20 public override token;

    ISgBridge public sgBridge;
    IStargateRouter public router;

    uint256 public totalDebtRatio;
    mapping(uint16 => mapping(address => StrategyParams)) public strategies;
    uint256 public activeStrategies;

    mapping(uint16 => EnumerableSet.AddressSet) internal _strategiesByChainId;
    EnumerableSet.UintSet internal _supportedChainIds;

    uint256 internal _depositEpoch;
    uint256 internal _withdrawEpoch;
    mapping(uint256 => DepositEpoch) internal _depositEpochs;
    mapping(uint256 => WithdrawEpoch) internal _withdrawEpochs;

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
        require(
            totalDebtRatio + _debtRatio <= MAX_BPS,
            "Vault::DebtRatioExceeded"
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
        activeStrategies++;
        totalDebtRatio += _debtRatio;
    }

    function initiateDeposit(uint256 _amount) external override {
        token.safeTransferFrom(msg.sender, address(this), _amount);
        _depositEpochs[_depositEpoch].requests.push(
            DepositRequest({amount: _amount, user: msg.sender})
        );
    }

    function initiateWithdraw(
        uint256 _shares,
        uint256 _maxLoss
    ) external override {
        IERC20(address(this)).safeTransferFrom(
            msg.sender,
            address(this),
            _shares
        );

        _withdrawEpochs[_withdrawEpoch].requests.push(
            WithdrawRequest({
                shares: _shares,
                maxLoss: _maxLoss,
                user: msg.sender
            })
        );
    }

    function handleDeposits() external override onlyAuthorized {
        require(_isLastReportValid(), "Vault::LastReportInvalid");

        uint256 requestsLength = _depositEpochs[_depositEpoch].requests.length;
        require(requestsLength > 0, "Vault::NoDepositRequests");

        (uint256 assets, ) = totalAssets();
        for (uint256 i = 0; i < requestsLength; i++) {
            DepositRequest storage request = _depositEpochs[_depositEpoch]
                .requests[i];
            _issueSharesForAmount(request.user, request.amount, assets);
        }
        _depositEpoch++;
    }

    function handleWithdrawals() external override onlyAuthorized {
        require(_isLastReportValid(), "Vault::LastReportInvalid");
        require(
            !_withdrawEpochs[_withdrawEpoch].inProgress,
            "Vault::AlreadyInProgress"
        );

        uint256 requestsLength = _withdrawEpochs[_withdrawEpoch]
            .requests
            .length;
        require(requestsLength > 0, "Vault::NoWithdrawRequests");

        _withdrawEpochs[_withdrawEpoch].approveExpected = activeStrategies;
        uint256 vaultBalance = token.balanceOf(address(this));

        uint256 sharesToWithdraw = 0;
        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[_withdrawEpoch]
                .requests[i];
            sharesToWithdraw += request.shares;
        }
        (uint256 assets, ) = totalAssets();
        uint256 withdrawValue = _shareValue(sharesToWithdraw, assets);
        uint256 toWithdrawFromStrategies = withdrawValue > vaultBalance
            ? withdrawValue - vaultBalance
            : 0;

        if (toWithdrawFromStrategies == 0) {
            _fulfillWithdrawEpoch();
            return;
        }

        _withdrawEpochs[_withdrawEpoch].inProgress = true;
        for (uint256 i = 0; i < _supportedChainIds.length(); i++) {
            uint16 chainId = uint16(_supportedChainIds.at(i));
            EnumerableSet.AddressSet
                storage strategiesByChainId = _strategiesByChainId[chainId];

            for (uint256 j = 0; j < strategiesByChainId.length(); j++) {
                address strategy = strategiesByChainId.at(j);
                StrategyParams storage params = strategies[chainId][strategy];
                if (params.debtRatio > 0) {
                    uint256 valueToWithdraw = (toWithdrawFromStrategies *
                        params.debtRatio) / totalDebtRatio;
                    if (valueToWithdraw > 0) {
                        _requestToWithdrawFromStrategy(
                            chainId,
                            strategy,
                            valueToWithdraw
                        );
                    }
                }
            }
        }
    }

    function pricePerShare() external view override returns (uint256) {
        (uint256 assets, ) = totalAssets();
        return _shareValue(10 ** decimals(), assets);
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

    function _shareValue(
        uint256 _shares,
        uint256 _totalAssets
    ) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return _shares;
        }
        return (_shares * _totalAssets) / totalSupply();
    }

    function _issueSharesForAmount(
        address _to,
        uint256 _amount,
        uint256 _totalAssets
    ) internal returns (uint256) {
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _totalAssets;
        }
        require(shares > 0, "Vault::ZeroShares");
        _mint(_to, shares);
        return shares;
    }

    function _isLastReportValid() internal view returns (bool) {
        (, uint256 lastReport) = totalAssets();
        return
            lastReport > 0 &&
            block.timestamp - lastReport < VALID_REPORT_THRESHOLD;
    }

    function _requestToWithdrawFromStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _valueToWithdraw
    ) internal {
        StrategyParams storage params = strategies[_chainId][_strategy];
        require(params.activation > 0, "Vault::InactiveStrategy");

        uint256 valueToWithdraw = _valueToWithdraw;
        bytes memory payload = abi.encode(
            MessageType.WithdrawSomeRequest,
            WithdrawSomeRequest({amount: valueToWithdraw, id: _withdrawEpoch})
        );
        bytes memory remoteAndLocalAddresses = abi.encodePacked(
            _strategy,
            address(this)
        );
        (uint256 nativeFee, ) = lzEndpoint.estimateFees(
            _chainId,
            address(this),
            payload,
            false,
            bytes("")
        );
        if (address(this).balance < nativeFee) {
            revert InsufficientFunds(nativeFee, address(this).balance);
        }
        lzEndpoint.send{value: nativeFee}(
            _chainId,
            remoteAndLocalAddresses,
            payload,
            payable(address(this)),
            address(this),
            bytes("")
        );
    }

    function _fulfillWithdrawEpoch() internal {
        uint256 requestsLength = _withdrawEpochs[_withdrawEpoch]
            .requests
            .length;
        require(requestsLength > 0, "Vault::NoWithdrawRequests");

        (uint256 assets, ) = totalAssets();
        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[_withdrawEpoch]
                .requests[i];
            uint256 valueToTransfer = Math.min(
                _shareValue(request.shares, assets),
                IERC20(token).balanceOf(address(this))
            );
            if (valueToTransfer > 0) {
                token.safeTransfer(request.user, valueToTransfer);
            }
        }
        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[_withdrawEpoch]
                .requests[i];
            _burn(request.user, request.shares);
        }
        _withdrawEpoch++;
    }

    function _handleWithdrawSomeResponse(
        uint16 _chainId,
        WithdrawSomeResponse memory _message
    ) internal {
        require(
            strategies[_chainId][_message.source].activation > 0,
            "Vault::InactiveStrategy"
        );
        _withdrawEpochs[_message.id].approveExpected++;
        if (
            _withdrawEpochs[_message.id].approveExpected ==
            _withdrawEpochs[_message.id].approveActual
        ) {
            _fulfillWithdrawEpoch();
        }
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal override {
        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );
        require(
            strategies[_srcChainId][srcAddress].activation > 0,
            "Vault::IncorrectSender"
        );

        MessageType messageType = abi.decode(_payload, (MessageType));
        if (messageType == MessageType.ReportTotalAssetsResponse) {
            (, ReportTotalAssetsResponse memory message) = abi.decode(
                _payload,
                (uint256, ReportTotalAssetsResponse)
            );
            strategies[_srcChainId][srcAddress].lastReport = message.timestamp;
            strategies[_srcChainId][srcAddress]
                .lastReportedTotalAssets = message.totalAssets;
        }
    }

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
            _handleWithdrawSomeResponse(_srcChainId, message);
        }

        emit SgReceived(_token, _amountLD, srcAddress);
    }

    receive() external payable {}
}
