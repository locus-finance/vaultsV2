// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import {NonblockingLzAppUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IStargateRouter, IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";
import {StrategyParams, WithdrawRequest, WithdrawEpoch, IVault} from "./interfaces/IVault.sol";

contract Vault is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    NonblockingLzAppUpgradeable,
    IVault,
    IStrategyMessages,
    IStargateReceiver
{
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    function initialize(
        address _governance,
        address _lzEndpoint,
        IERC20 _token,
        address _sgBridge,
        address _router
    ) external override initializer {
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);
        __Ownable_init();
        __ERC20_init("Omnichain Vault", "OMV");

        governance = _governance;
        token = _token;
        sgBridge = ISgBridge(_sgBridge);
        router = IStargateRouter(_router);

        token.approve(address(sgBridge), type(uint256).max);
    }

    uint256 public constant VALID_REPORT_THRESHOLD = 6 hours;
    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant DEFAULT_MAX_LOSS = 2_000;

    address public override governance;
    IERC20 public override token;

    ISgBridge public sgBridge;
    IStargateRouter public router;

    uint256 public totalDebtRatio;
    uint256 public totalDebt;
    bool public emergencyShutdown;
    mapping(uint16 => mapping(address => StrategyParams)) public strategies;
    uint256 public withdrawEpoch;

    mapping(uint16 => EnumerableSet.AddressSet) internal _strategiesByChainId;
    EnumerableSet.UintSet internal _supportedChainIds;
    mapping(uint256 => WithdrawEpoch) internal _withdrawEpochs;

    modifier onlyAuthorized() {
        require(
            msg.sender == governance || msg.sender == owner(),
            "Vault::Unauthorized"
        );
        _;
    }

    function revokeFunds() external override onlyAuthorized {
        payable(owner()).transfer(address(this).balance);
    }

    function sweepToken(IERC20 _token) external override onlyAuthorized {
        _token.safeTransfer(msg.sender, _token.balanceOf(address(this)));
    }

    function setEmergencyShutdown(
        bool _emergencyShutdown
    ) external onlyAuthorized {
        emergencyShutdown = _emergencyShutdown;
    }

    function totalAssets() public view override returns (uint256) {
        return totalDebt + totalIdle();
    }

    function totalIdle() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function deposit(uint256 _amount) external override returns (uint256) {
        return _deposit(_amount, msg.sender);
    }

    function deposit(
        uint256 _amount,
        address _recipient
    ) external override returns (uint256) {
        return _deposit(_amount, _recipient);
    }

    function withdraw() external override {
        _initiateWithdraw(balanceOf(msg.sender), msg.sender, DEFAULT_MAX_LOSS);
    }

    function withdraw(uint256 _maxShares, uint256 _maxLoss) external override {
        _initiateWithdraw(_maxShares, msg.sender, _maxLoss);
    }

    function withdraw(
        uint256 _maxShares,
        address _recipient,
        uint256 _maxLoss
    ) external override {
        _initiateWithdraw(_maxShares, _recipient, _maxLoss);
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
            activation: block.timestamp,
            debtRatio: _debtRatio,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0,
            lastReport: 0,
            performanceFee: _performanceFee,
            enabled: true
        });

        _strategiesByChainId[_chainId].add(_strategy);
        _supportedChainIds.add(uint256(_chainId));
        totalDebtRatio += _debtRatio;
    }

    function debtOutstanding(
        uint16 _chainId,
        address _strategy
    ) external view returns (uint256) {
        return _debtOutstanding(_chainId, _strategy);
    }

    function creditAvailable(
        uint16 _chainId,
        address _strategy
    ) external view returns (uint256) {
        return _creditAvailable(_chainId, _strategy);
    }

    function retryWithdrawFromStrategyInEpoch(
        uint16 _chainId,
        address _strategy
    ) external onlyAuthorized {
        _sendMessageToStrategy(
            _chainId,
            _strategy,
            abi.encode(
                MessageType.WithdrawSomeRequest,
                WithdrawSomeRequest({
                    id: withdrawEpoch,
                    amount: _withdrawEpochs[withdrawEpoch].requestedAmount[
                        _chainId
                    ][_strategy]
                })
            )
        );
    }

    function handleWithdrawals() external override onlyAuthorized {
        require(_isLastReportValid(), "Vault::InvalidLastReport");
        require(
            !_withdrawEpochs[withdrawEpoch].inProgress,
            "Vault::WithdrawalAlreadyInProgress"
        );

        uint256 withdrawValue = 0;
        for (
            uint256 i = 0;
            i < _withdrawEpochs[withdrawEpoch].requests.length;
            i++
        ) {
            WithdrawRequest storage request = _withdrawEpochs[withdrawEpoch]
                .requests[i];
            withdrawValue += _shareValue(request.shares);
        }

        if (withdrawValue <= totalIdle()) {
            _fulfillWithdrawEpoch();
            return;
        }

        uint256 amountNeeded = withdrawValue - totalIdle();
        uint256 strategyRequested = 0;

        for (
            uint256 i = 0;
            i < _supportedChainIds.length() && amountNeeded > 0;
            i++
        ) {
            uint16 chainId = uint16(_supportedChainIds.at(i));
            EnumerableSet.AddressSet
                storage strategiesByChainId = _strategiesByChainId[chainId];

            for (
                uint256 j = 0;
                j < strategiesByChainId.length() && amountNeeded > 0;
                j++
            ) {
                address strategy = strategiesByChainId.at(j);
                StrategyParams storage params = strategies[chainId][strategy];

                if (params.totalDebt > 0) {
                    continue;
                }

                uint256 strategyRequest = Math.min(
                    amountNeeded,
                    params.totalDebt
                );
                _withdrawEpochs[withdrawEpoch].requestedAmount[chainId][
                    strategy
                ] = strategyRequest;
                amountNeeded -= strategyRequest;

                _sendMessageToStrategy(
                    chainId,
                    strategy,
                    abi.encode(
                        MessageType.WithdrawSomeRequest,
                        WithdrawSomeRequest({
                            id: withdrawEpoch,
                            amount: strategyRequest
                        })
                    )
                );
                strategyRequested++;
            }
        }

        _withdrawEpochs[withdrawEpoch].approveExpected = strategyRequested;
        _withdrawEpochs[withdrawEpoch].inProgress = true;
    }

    function pricePerShare() external view override returns (uint256) {
        return _shareValue(10 ** decimals());
    }

    function revokeStrategy(
        uint16 _chainId,
        address _strategy
    ) external override onlyAuthorized {
        _revokeStrategy(_chainId, _strategy);
    }

    function updateStrategyDebtRatio(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio
    ) external override onlyAuthorized {
        require(
            strategies[_chainId][_strategy].activation > 0,
            "Vault::InactiveStrategy"
        );

        totalDebtRatio -= strategies[_chainId][_strategy].debtRatio;
        strategies[_chainId][_strategy].debtRatio = _debtRatio;

        require(
            totalDebtRatio + _debtRatio <= MAX_BPS,
            "Vault::DebtRatioExceeded"
        );
        totalDebtRatio += _debtRatio;
    }

    function migrateStrategy(
        uint16 _chainId,
        address _oldStrategy,
        address _newStrategy
    ) external onlyAuthorized {
        require(_newStrategy != address(0), "Vault::ZeroAddress");
        require(
            strategies[_chainId][_oldStrategy].activation > 0,
            "Vault::InactiveStrategy"
        );
        require(
            strategies[_chainId][_newStrategy].activation == 0,
            "Vault::AlreadyActivated"
        );
        _revokeStrategy(_chainId, _oldStrategy);
    }

    function sgReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint,
        address _token,
        uint256 _amountLD,
        bytes memory _payload
    ) external override {
        require(_token == address(token), "Vault::InvalidToken");
        require(
            msg.sender == address(router) || msg.sender == address(sgBridge),
            "Vault::RouterOrBridgeOnly"
        );

        address srcAddress = address(
            bytes20(abi.encodePacked(_srcAddress.slice(0, 20)))
        );

        _handlePayload(_srcChainId, _payload, _amountLD);

        emit SgReceived(_token, _amountLD, srcAddress);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual override {
        require(
            msg.sender == address(lzEndpoint),
            "Vault::InvalidEndpointCaller"
        );

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _deposit(
        uint256 _amount,
        address _recipient
    ) internal returns (uint256) {
        require(!emergencyShutdown, "Vault::EmergencyShutdown");
        uint256 shares = _issueSharesForAmount(_recipient, _amount);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        return shares;
    }

    function _handlePayload(
        uint16 _chainId,
        bytes memory _payload,
        uint256 _receivedTokens
    ) internal {
        MessageType messageType = abi.decode(_payload, (MessageType));
        if (messageType == MessageType.StrategyReport) {
            (, StrategyReport memory message) = abi.decode(
                _payload,
                (uint256, StrategyReport)
            );
            _handleStrategyReport(_chainId, message, _receivedTokens);
        } else if (messageType == MessageType.WithdrawSomeResponse) {
            (, WithdrawSomeResponse memory message) = abi.decode(
                _payload,
                (uint256, WithdrawSomeResponse)
            );
            _handleWithdrawSomeResponse(_chainId, message);
        }
    }

    function _handleStrategyReport(
        uint16 _chainId,
        StrategyReport memory _message,
        uint256 _receivedTokens
    ) internal {
        require(
            strategies[_chainId][_message.strategy].activation > 0,
            "Vault::InactiveStrategy"
        );

        if (_message.loss > 0) {
            _reportLoss(_chainId, _message.strategy, _message.loss);
        }

        strategies[_chainId][_message.strategy].totalGain += _message.profit;
        uint256 debt = _debtOutstanding(_chainId, _message.strategy);
        uint256 debtPayment = Math.min(debt, _message.debtPayment);

        if (debtPayment > 0) {
            strategies[_chainId][_message.strategy].totalDebt -= debtPayment;
            totalDebt -= debtPayment;
            debt -= debtPayment;
        }

        if (_message.creditAvailable > 0) {
            strategies[_chainId][_message.strategy].totalDebt += _message
                .creditAvailable;
            totalDebt += _message.creditAvailable;
        }

        strategies[_chainId][_message.strategy].lastReport = _message.timestamp;

        if (
            strategies[_chainId][_message.strategy].debtRatio == 0 ||
            emergencyShutdown
        ) {
            debt = _message.totalAssets;
        }

        if (_message.giveToStrategy > 0) {
            sgBridge.bridge(
                address(token),
                _message.giveToStrategy,
                _chainId,
                _message.strategy,
                abi.encode(
                    MessageType.AdjustPositionRequest,
                    AdjustPositionRequest({debtOutstanding: debt})
                )
            );
        } else {
            _sendMessageToStrategy(
                _chainId,
                _message.strategy,
                abi.encode(
                    MessageType.AdjustPositionRequest,
                    AdjustPositionRequest({debtOutstanding: debt})
                )
            );
        }

        StrategyParams memory params = strategies[_chainId][_message.strategy];
        emit StrategyReported(
            _chainId,
            _message.strategy,
            _message.profit,
            _message.loss,
            _message.debtPayment,
            params.totalGain,
            params.totalLoss,
            params.totalDebt,
            _message.creditAvailable,
            params.debtRatio,
            _receivedTokens
        );
    }

    function _reportLoss(
        uint16 _chainId,
        address _strategy,
        uint256 _loss
    ) internal {
        require(
            strategies[_chainId][_strategy].totalDebt >= _loss,
            "Vault::IncorrectReport"
        );
        strategies[_chainId][_strategy].totalLoss += _loss;
        strategies[_chainId][_strategy].totalDebt -= _loss;
        totalDebt -= _loss;
    }

    function _initiateWithdraw(
        uint256 _shares,
        address _recipient,
        uint256 _maxLoss
    ) internal {
        require(
            !_withdrawEpochs[withdrawEpoch].inProgress,
            "Vault::WithdrawalEpochInProgress"
        );

        _transfer(msg.sender, address(this), _shares);
        _withdrawEpochs[withdrawEpoch].requests.push(
            WithdrawRequest({
                author: msg.sender,
                user: _recipient,
                shares: _shares,
                maxLoss: _maxLoss,
                expected: _shareValue(_shares),
                success: false
            })
        );
    }

    function _shareValue(uint256 _shares) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return _shares;
        }
        return (_shares * totalAssets()) / totalSupply();
    }

    function _issueSharesForAmount(
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / totalAssets();
        }
        require(shares > 0, "Vault::ZeroShares");
        _mint(_to, shares);
        return shares;
    }

    function _getLastReportTimestamp() internal view returns (uint256) {
        uint256 lastReport = type(uint256).max;

        for (uint256 i = 0; i < _supportedChainIds.length(); i++) {
            uint16 chainId = uint16(_supportedChainIds.at(i));
            EnumerableSet.AddressSet
                storage strategiesByChainId = _strategiesByChainId[chainId];

            for (uint256 j = 0; j < strategiesByChainId.length(); j++) {
                address strategy = strategiesByChainId.at(j);
                StrategyParams storage params = strategies[chainId][strategy];
                if (params.totalDebt > 0) {
                    lastReport = Math.min(lastReport, params.lastReport);
                }
            }
        }

        return lastReport;
    }

    function _isLastReportValid() internal view returns (bool) {
        uint256 lastReport = _getLastReportTimestamp();
        return block.timestamp - lastReport < VALID_REPORT_THRESHOLD;
    }

    function _sendMessageToStrategy(
        uint16 _chainId,
        address _strategy,
        bytes memory _payload
    ) internal {
        StrategyParams storage params = strategies[_chainId][_strategy];
        require(params.activation > 0, "Vault::InactiveStrategy");

        bytes memory remoteAndLocalAddresses = abi.encodePacked(
            _strategy,
            address(this)
        );

        (uint256 nativeFee, ) = lzEndpoint.estimateFees(
            _chainId,
            address(this),
            _payload,
            false,
            _getAdapterParams()
        );

        if (address(this).balance < nativeFee) {
            revert InsufficientFunds(nativeFee, address(this).balance);
        }

        lzEndpoint.send{value: nativeFee}(
            _chainId,
            remoteAndLocalAddresses,
            _payload,
            payable(address(this)),
            address(this),
            _getAdapterParams()
        );
    }

    function _getAdapterParams() internal view virtual returns (bytes memory) {
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 1_000_000;
        return abi.encodePacked(version, gasForDestinationLzReceive);
    }

    function _revokeStrategy(uint16 _chainId, address _strategy) internal {
        totalDebtRatio -= strategies[_chainId][_strategy].debtRatio;
        strategies[_chainId][_strategy].debtRatio = 0;
    }

    function _creditAvailable(
        uint16 _chainId,
        address _strategy
    ) internal view returns (uint256) {
        if (emergencyShutdown) {
            return 0;
        }

        uint256 strategyDebtLimit = (strategies[_chainId][_strategy].debtRatio *
            totalAssets()) / MAX_BPS;
        uint256 strategyTotalDebt = strategies[_chainId][_strategy].totalDebt;

        if (strategyDebtLimit <= strategyTotalDebt) {
            return 0;
        }

        return Math.min(totalIdle(), strategyDebtLimit - strategyTotalDebt);
    }

    function _debtOutstanding(
        uint16 _chainId,
        address _strategy
    ) internal view returns (uint256) {
        uint256 strategyDebtLimit = (strategies[_chainId][_strategy].debtRatio *
            totalAssets()) / MAX_BPS;
        uint256 strategyTotalDebt = strategies[_chainId][_strategy].totalDebt;

        if (emergencyShutdown) {
            return strategyTotalDebt;
        } else if (strategyTotalDebt <= strategyDebtLimit) {
            return 0;
        } else {
            return strategyTotalDebt - strategyDebtLimit;
        }
    }

    function _fulfillWithdrawEpoch() internal {
        uint256 requestsLength = _withdrawEpochs[withdrawEpoch].requests.length;
        require(requestsLength > 0, "Vault::NoWithdrawRequests");

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[withdrawEpoch]
                .requests[i];
            uint256 valueToTransfer = Math.min(
                _shareValue(request.shares),
                totalIdle()
            );

            if (valueToTransfer < request.expected) {
                uint256 diff = request.expected - valueToTransfer;
                uint256 diffScaled = (diff * MAX_BPS) / request.expected;

                if (diffScaled > request.maxLoss) {
                    request.success = false;
                    this.transfer(request.author, request.shares);
                    continue;
                }
            }

            request.success = true;
            token.safeTransfer(request.user, valueToTransfer);
        }

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[withdrawEpoch]
                .requests[i];
            if (request.success) {
                _burn(address(this), request.shares);
            }
        }

        emit FulfilledWithdrawEpoch(withdrawEpoch, requestsLength);

        _withdrawEpochs[withdrawEpoch].inProgress = false;
        withdrawEpoch++;
    }

    function _handleWithdrawSomeResponse(
        uint16 _chainId,
        WithdrawSomeResponse memory _message
    ) internal {
        require(
            strategies[_chainId][_message.source].activation > 0,
            "Vault::InactiveStrategy"
        );

        if (_message.loss > 0) {
            _reportLoss(_chainId, _message.source, _message.loss);
        }
        strategies[_chainId][_message.source].totalDebt -= _message.amount;
        totalDebt -= _message.amount;

        _withdrawEpochs[_message.id].approveActual++;
        _withdrawEpochs[_message.id].approved[_chainId][_message.source] = true;
        if (
            _withdrawEpochs[_message.id].approveExpected ==
            _withdrawEpochs[_message.id].approveActual
        ) {
            _fulfillWithdrawEpoch();
        }

        emit StrategyWithdrawnSome(
            _chainId,
            _message.source,
            _message.amount,
            _message.loss,
            _message.id
        );
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

        _handlePayload(_srcChainId, _payload, 0);
    }

    receive() external payable {}

    /* === DEBUG FUNCTIONS === */

    function clearWant() external onlyAuthorized {
        token.safeTransfer(address(1), token.balanceOf(address(this)));
    }

    function callMe() external {}
}
