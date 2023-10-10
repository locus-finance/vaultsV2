// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BytesLib} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import {NonblockingLzAppUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ISgBridge} from "./interfaces/ISgBridge.sol";
import {IStargateReceiver} from "./integrations/stargate/IStargate.sol";
import {IStrategyMessages} from "./interfaces/IStrategyMessages.sol";
import {StrategyParams, WithdrawRequest, WithdrawEpoch, IVault} from "./interfaces/IVault.sol";
import {IBaseStrategy} from "./interfaces/IBaseStrategy.sol";

contract Vault is
    Initializable,
    ERC20Upgradeable,
    NonblockingLzAppUpgradeable,
    IVault,
    IStrategyMessages,
    IStargateReceiver
{
    error Vault__V1();
    error Vault__V2();
    error Vault__V3();
    error Vault__V4();
    error Vault__V5();
    error Vault__V6();
    error Vault__V7();
    error Vault__V8();
    error Vault__V9();
    error Vault__V10();
    error Vault__V11();
    error Vault__V12();
    error Vault__V13();
    error Vault__V14();
    error Vault__V15();
    error Vault__V16();
    error Vault__V17();

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    function initialize(
        address _governance,
        address _lzEndpoint,
        IERC20 _token,
        address _sgRouter
    ) external override initializer {
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);
        __Ownable_init();
        __ERC20_init("Omnichain Vault", "OMV");

        governance = _governance;
        token = _token;
        sgRouter = _sgRouter;
    }

    uint16 internal constant VAULT_CHAIN_ID = 116;
    address public override governance;
    IERC20 public override token;

    ISgBridge public sgBridge;
    uint256 public totalDebtRatio;
    uint256 public totalDebt;
    bool public emergencyShutdown;
    mapping(uint16 => mapping(address => StrategyParams)) public strategies;
    uint256 public withdrawEpoch;

    mapping(uint16 => EnumerableSet.AddressSet) internal _strategiesByChainId;
    EnumerableSet.UintSet internal _supportedChainIds;
    mapping(uint256 => WithdrawEpoch) public withdrawEpochs;
    mapping(uint16 => mapping(address => mapping(uint256 => bool)))
        internal _usedNonces;
    address public sgRouter;

    modifier onlyAuthorized() {
        if (msg.sender != governance || msg.sender != owner())
            revert Vault__V1();
        _;
    }

    modifier isAction(uint16 _chainId, address _strategy) {
        if (strategies[_chainId][_strategy].activation == 0) revert Vault__V2();
        _;
    }

    modifier nonAction(uint16 _chainId, address _strategy) {
        if (strategies[_chainId][_strategy].activation > 0) revert Vault__V3();
        _;
    }

    modifier WithdrawInProgress() {
        if (withdrawEpochs[withdrawEpoch].inProgress) revert Vault__V4();
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20Upgradeable(address(token)).decimals();
    }

    function revokeFunds() external override onlyAuthorized {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setEmergencyShutdown(
        bool _emergencyShutdown
    ) external onlyAuthorized {
        emergencyShutdown = _emergencyShutdown;
    }

    function setGovernance(address _newGovernance) external onlyAuthorized {
        governance = _newGovernance;
    }

    function setSgBridge(address _newSgBridge) external onlyAuthorized {
        token.approve(_newSgBridge, type(uint256).max);
        sgBridge = ISgBridge(_newSgBridge);
    }

    function setStrategist(
        uint16 _chainId,
        address _strategy,
        address _newStrategist
    ) external onlyAuthorized {
        strategies[_chainId][_strategy].strategist = _newStrategist;
    }

    function totalAssets() public view override returns (uint256) {
        return totalDebt + totalIdle();
    }

    function totalIdle() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function deposit(
        uint256 _amount,
        address _recipient
    ) public override returns (uint256) {
        if (emergencyShutdown) revert Vault__V11();
        uint256 shares = _issueSharesForAmount(_recipient, _amount);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        return shares;
    }

    function withdraw(
        uint256 _maxShares,
        address _recipient,
        uint256 _maxLoss
    ) public override WithdrawInProgress {
        _transfer(msg.sender, address(this), _maxShares);
        withdrawEpochs[withdrawEpoch].requests.push(
            WithdrawRequest({
                author: msg.sender,
                user: _recipient,
                shares: _maxShares,
                maxLoss: _maxLoss,
                expected: _shareValue(_maxShares),
                success: false
            })
        );
    }

    function addStrategy(
        uint16 _chainId,
        address _strategy,
        uint256 _debtRatio,
        uint256 _performanceFee,
        address _strategist
    ) external override onlyAuthorized nonAction(_chainId, _strategy) {
        if (totalDebtRatio + _debtRatio > 10_000) revert Vault__V5();

        strategies[_chainId][_strategy] = StrategyParams({
            activation: block.timestamp,
            debtRatio: _debtRatio,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0,
            lastReport: 0,
            performanceFee: _performanceFee,
            strategist: _strategist
        });

        _strategiesByChainId[_chainId].add(_strategy);
        _supportedChainIds.add(uint256(_chainId));
        totalDebtRatio += _debtRatio;
    }

    function debtOutstanding(
        uint16 _chainId,
        address _strategy
    ) public view returns (uint256) {
        uint256 strategyDebtLimit = (strategies[_chainId][_strategy].debtRatio *
            totalAssets()) / 10_000;
        uint256 strategyTotalDebt = strategies[_chainId][_strategy].totalDebt;

        if (emergencyShutdown) {
            return strategyTotalDebt;
        } else if (strategyTotalDebt <= strategyDebtLimit) {
            return 0;
        } else {
            return strategyTotalDebt - strategyDebtLimit;
        }
    }

    function creditAvailable(
        uint16 _chainId,
        address _strategy
    ) external view returns (uint256) {
        return _creditAvailable(_chainId, _strategy);
    }

    function handleWithdrawals()
        external
        override
        onlyAuthorized
        WithdrawInProgress
    {
        uint256 withdrawValue = 0;
        for (
            uint256 i = 0;
            i < withdrawEpochs[withdrawEpoch].requests.length;
            i++
        ) {
            WithdrawRequest storage request = withdrawEpochs[withdrawEpoch]
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

                if (params.totalDebt == 0) {
                    continue;
                }

                uint256 strategyRequest = Math.min(
                    amountNeeded,
                    params.totalDebt
                );
                withdrawEpochs[withdrawEpoch].requestedAmount[chainId][
                        strategy
                    ] = strategyRequest;
                amountNeeded -= strategyRequest;
                if (VAULT_CHAIN_ID == chainId) {
                    IBaseStrategy(strategy).withdraw(strategyRequest);
                } else {
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
                }
                strategyRequested++;
            }
        }

        withdrawEpochs[withdrawEpoch].approveExpected = strategyRequested;
        withdrawEpochs[withdrawEpoch].inProgress = true;
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
        totalDebtRatio -= strategies[_chainId][_strategy].debtRatio;
        strategies[_chainId][_strategy].debtRatio = _debtRatio;
        if (totalDebtRatio + _debtRatio > 10_000) revert Vault__V6();
        totalDebtRatio += _debtRatio;
    }

    function migrateStrategy(
        uint16 _chainId,
        address _oldStrategy,
        address _newStrategy
    ) external onlyAuthorized nonAction(_chainId, _newStrategy) {
        if (_newStrategy == address(0)) revert Vault__V7();

        StrategyParams memory params = strategies[_chainId][_oldStrategy];
        strategies[_chainId][_newStrategy] = StrategyParams({
            activation: params.lastReport,
            debtRatio: params.debtRatio,
            totalDebt: params.totalDebt,
            totalGain: 0,
            totalLoss: 0,
            lastReport: params.lastReport,
            performanceFee: params.performanceFee,
            strategist: params.strategist
        });
        strategies[_chainId][_oldStrategy].debtRatio = 0;
        strategies[_chainId][_oldStrategy].totalDebt = 0;
        if (VAULT_CHAIN_ID == _chainId) {
            IBaseStrategy(_oldStrategy).migrate(_newStrategy);
        } else {
            _sendMessageToStrategy(
                _chainId,
                _oldStrategy,
                abi.encode(
                    MessageType.MigrateStrategyRequest,
                    MigrateStrategyRequest({newStrategy: _newStrategy})
                )
            );
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
        if (_token != address(token)) revert Vault__V8();
        if (
            msg.sender != address(sgRouter) ||
            msg.sender != address(sgBridge) ||
            msg.sender != owner()
        ) revert Vault__V9();

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
        if (msg.sender != address(lzEndpoint)) revert Vault__V10();

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
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
        _verifySignature(_chainId, _message);

        if (_message.loss > 0) {
            _reportLoss(_chainId, _message.strategy, _message.loss);
        }

        strategies[_chainId][_message.strategy].totalGain += _message.profit;
        uint256 debt = debtOutstanding(_chainId, _message.strategy);
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
        if (VAULT_CHAIN_ID == _chainId) {
            IBaseStrategy(_message.strategy).adjustPosition(debt);
        } else {
            if (_message.giveToStrategy > 0) {
                _bridge(
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
        if (strategies[_chainId][_strategy].totalDebt < _loss)
            revert Vault__V12();
        strategies[_chainId][_strategy].totalLoss += _loss;
        strategies[_chainId][_strategy].totalDebt -= _loss;
        totalDebt -= _loss;
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
        if (shares == 0) revert Vault__V13();
        _mint(_to, shares);
        return shares;
    }

    function _sendMessageToStrategy(
        uint16 _chainId,
        address _strategy,
        bytes memory _payload
    ) internal isAction(_chainId, _strategy) {
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
            totalAssets()) / 10_000;
        uint256 strategyTotalDebt = strategies[_chainId][_strategy].totalDebt;

        if (strategyDebtLimit <= strategyTotalDebt) {
            return 0;
        }

        return Math.min(totalIdle(), strategyDebtLimit - strategyTotalDebt);
    }

    // function _debtOutstanding(
    //     uint16 _chainId,
    //     address _strategy
    // ) internal view returns (uint256) {
    //     uint256 strategyDebtLimit = (strategies[_chainId][_strategy].debtRatio *
    //         totalAssets()) / 10_000;
    //     uint256 strategyTotalDebt = strategies[_chainId][_strategy].totalDebt;

    //     if (emergencyShutdown) {
    //         return strategyTotalDebt;
    //     } else if (strategyTotalDebt <= strategyDebtLimit) {
    //         return 0;
    //     } else {
    //         return strategyTotalDebt - strategyDebtLimit;
    //     }
    // }

    function _fulfillWithdrawEpoch() internal {
        uint256 requestsLength = withdrawEpochs[withdrawEpoch].requests.length;
        if (requestsLength == 0) revert Vault__V14();

        uint256[] memory shareValues = new uint256[](requestsLength);

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = withdrawEpochs[withdrawEpoch]
                .requests[i];
            shareValues[i] = _shareValue(request.shares);
        }

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = withdrawEpochs[withdrawEpoch]
                .requests[i];
            uint256 valueToTransfer = Math.min(shareValues[i], totalIdle());

            if (valueToTransfer < request.expected) {
                uint256 diff = request.expected - valueToTransfer;
                uint256 diffScaled = (diff * 10_000) / request.expected;

                if (diffScaled > request.maxLoss) {
                    request.success = false;
                    this.transfer(request.author, request.shares);
                    continue;
                }
            }

            request.success = true;
            token.safeTransfer(request.user, valueToTransfer);
            _burn(address(this), request.shares);
        }

        emit FulfilledWithdrawEpoch(withdrawEpoch, requestsLength);

        withdrawEpochs[withdrawEpoch].inProgress = false;
        withdrawEpoch++;
    }

    function _handleWithdrawSomeResponse(
        uint16 _chainId,
        WithdrawSomeResponse memory _message
    ) internal isAction(_chainId, _message.source) {
        if (_message.loss > 0) {
            _reportLoss(_chainId, _message.source, _message.loss);
        }
        strategies[_chainId][_message.source].totalDebt -= _message.amount;
        totalDebt -= _message.amount;

        withdrawEpochs[_message.id].approveActual++;
        withdrawEpochs[_message.id].approved[_chainId][_message.source] = true;
        if (
            withdrawEpochs[_message.id].approveExpected ==
            withdrawEpochs[_message.id].approveActual
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
        if (strategies[_srcChainId][srcAddress].activation == 0)
            revert Vault__V15();

        _handlePayload(_srcChainId, _payload, 0);
    }

    function _bridge(
        uint256 _amount,
        uint16 _destChainId,
        address _dest,
        bytes memory _payload
    ) internal {
        uint256 fee = sgBridge.feeForBridge(_destChainId, _dest, _payload);
        sgBridge.bridge{value: fee}(
            address(token),
            _amount,
            _destChainId,
            _dest,
            _payload
        );
    }

    function _verifySignature(
        uint16 _chainId,
        StrategyReport memory _report
    ) internal {
        if (_usedNonces[_chainId][_report.strategy][_report.nonce] != false)
            revert Vault__V16();
        bytes32 messageHash = keccak256(
            abi.encodePacked(_report.strategy, _report.nonce, _chainId)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        if (
            ECDSA.recover(ethSignedMessageHash, _report.signature) !=
            strategies[_chainId][_report.strategy].strategist
        ) revert Vault__V17();

        _usedNonces[_chainId][_report.strategy][_report.nonce] = true;
    }

    receive() external payable {}
}
