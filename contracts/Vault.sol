// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BytesLib } from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import { NonblockingLzAppUpgradeable } from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { ISgBridge } from "./interfaces/ISgBridge.sol";
import { IStargateReceiver } from "./integrations/stargate/IStargate.sol";
import { IStrategyMessages } from "./interfaces/IStrategyMessages.sol";
import { StrategyParams, WithdrawRequest, WithdrawEpoch, IVault } from "./interfaces/IVault.sol";
import { IBaseStrategy } from "./interfaces/IBaseStrategy.sol";

contract Vault is
    Initializable,
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
        address _sgRouter
    ) external override initializer {
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);
        __Ownable_init();
        __ERC20_init("Omnichain Vault", "OMV");

        governance = _governance;
        token = _token;
        sgBridge = ISgBridge(_sgBridge);
        sgRouter = _sgRouter;

        token.approve(_sgBridge, type(uint256).max);
        //Optimism
        _LzIdToNaturalId[111] = 10;
        //polygon
        _LzIdToNaturalId[109] = 137;
        //arbitrum
        _LzIdToNaturalId[110] = 42161;
        //base
        _LzIdToNaturalId[184] = 8453;
    }

    uint256 public constant MAX_BPS = 10_000;

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
    mapping(uint256 => WithdrawEpoch) internal _withdrawEpochs;
    mapping(uint16 => mapping(address => mapping(uint256 => bool)))
        internal _usedNonces;
    mapping(uint16 lzChainId => uint256 nativeChainId)
        internal _LzIdToNaturalId;

    address public sgRouter;

    modifier onlyAuthorized() {
        require(msg.sender == governance || msg.sender == owner(), "V1");
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(address(token)).decimals();
    }

    function revokeFunds() external override onlyAuthorized {
        payable(msg.sender).transfer(address(this).balance);
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

    function addChain(
        uint16 _lzChainId,
        uint256 _naturalChainId
    ) external onlyAuthorized {
        _LzIdToNaturalId[_lzChainId] = _naturalChainId;
    }

    function deposit(
        uint256 _amount,
        address _recipient
    ) external override returns (uint256) {
        return _deposit(_amount, _recipient);
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
        uint256 _performanceFee,
        address _strategist
    ) external override onlyAuthorized {
        require(strategies[_chainId][_strategy].activation == 0, "V2");
        require(totalDebtRatio + _debtRatio <= MAX_BPS, "V3");

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
    ) external view returns (uint256) {
        return _debtOutstanding(_chainId, _strategy);
    }

    function creditAvailable(
        uint16 _chainId,
        address _strategy
    ) external view returns (uint256) {
        return _creditAvailable(_chainId, _strategy);
    }

    function handleWithdrawals() external override onlyAuthorized {
        require(!_withdrawEpochs[withdrawEpoch].inProgress, "V4");

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

                if (params.totalDebt == 0) {
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
                if (block.chainid == _LzIdToNaturalId[chainId]) {
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

        require(strategyRequested > 0, "V5");

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

        require(totalDebtRatio + _debtRatio <= MAX_BPS, "V6");
        totalDebtRatio += _debtRatio;
    }

    function migrateStrategy(
        uint16 _chainId,
        address _oldStrategy,
        address _newStrategy
    ) external onlyAuthorized {
        require(_newStrategy != address(0), "V7");
        require(strategies[_chainId][_oldStrategy].activation > 0, "V8");
        require(strategies[_chainId][_newStrategy].activation == 0, "V9");

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
        if (block.chainid == _LzIdToNaturalId[_chainId]) {
            IBaseStrategy(_oldStrategy).migrate(_newStrategy);
        } else {
            _sendMessageToStrategy(
                _chainId,
                _oldStrategy,
                abi.encode(
                    MessageType.MigrateStrategyRequest,
                    MigrateStrategyRequest({ newStrategy: _newStrategy })
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
        require(_token == address(token), "V10");
        require(
            msg.sender == address(sgRouter) ||
                msg.sender == address(sgBridge) ||
                msg.sender == owner(),
            "V11"
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
        require(msg.sender == address(lzEndpoint), "V12");

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _deposit(
        uint256 _amount,
        address _recipient
    ) internal returns (uint256) {
        require(!emergencyShutdown, "V13");
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
        _verifySignature(_chainId, _message);

        require(strategies[_chainId][_message.strategy].activation > 0, "V14");

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
        if (block.chainid == _LzIdToNaturalId[_chainId]) {
            IBaseStrategy(_message.strategy).adjustPosition(debt);
        } else {
            if (_message.giveToStrategy > 0) {
                _bridge(
                    _message.giveToStrategy,
                    _chainId,
                    _message.strategy,
                    abi.encode(
                        MessageType.AdjustPositionRequest,
                        AdjustPositionRequest({ debtOutstanding: debt })
                    )
                );
            } else {
                _sendMessageToStrategy(
                    _chainId,
                    _message.strategy,
                    abi.encode(
                        MessageType.AdjustPositionRequest,
                        AdjustPositionRequest({ debtOutstanding: debt })
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
        require(strategies[_chainId][_strategy].totalDebt >= _loss, "V15");
        strategies[_chainId][_strategy].totalLoss += _loss;
        strategies[_chainId][_strategy].totalDebt -= _loss;
        totalDebt -= _loss;
    }

    function _initiateWithdraw(
        uint256 _shares,
        address _recipient,
        uint256 _maxLoss
    ) internal {
        require(!_withdrawEpochs[withdrawEpoch].inProgress, "V16");

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
        require(shares > 0, "V17");
        _mint(_to, shares);
        return shares;
    }

    function _sendMessageToStrategy(
        uint16 _chainId,
        address _strategy,
        bytes memory _payload
    ) internal {
        StrategyParams storage params = strategies[_chainId][_strategy];
        require(params.activation > 0, "V18");

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

        lzEndpoint.send{ value: nativeFee }(
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
        require(requestsLength > 0, "V19");

        uint256[] memory shareValues = new uint256[](requestsLength);

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[withdrawEpoch]
                .requests[i];
            shareValues[i] = _shareValue(request.shares);
        }

        for (uint256 i = 0; i < requestsLength; i++) {
            WithdrawRequest storage request = _withdrawEpochs[withdrawEpoch]
                .requests[i];
            uint256 valueToTransfer = Math.min(shareValues[i], totalIdle());

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
            _burn(address(this), request.shares);
        }

        emit FulfilledWithdrawEpoch(withdrawEpoch, requestsLength);

        _withdrawEpochs[withdrawEpoch].inProgress = false;
        withdrawEpoch++;
    }

    function _handleWithdrawSomeResponse(
        uint16 _chainId,
        WithdrawSomeResponse memory _message
    ) internal {
        require(strategies[_chainId][_message.source].activation > 0, "V20");

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
        require(strategies[_srcChainId][srcAddress].activation > 0, "V21");

        _handlePayload(_srcChainId, _payload, 0);
    }

    function _bridge(
        uint256 _amount,
        uint16 _destChainId,
        address _dest,
        bytes memory _payload
    ) internal {
        uint256 fee = sgBridge.feeForBridge(_destChainId, _dest, _payload);
        sgBridge.bridge{ value: fee }(
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
        require(
            _usedNonces[_chainId][_report.strategy][_report.nonce] == false,
            "V22"
        );
        bytes32 messageHash = keccak256(
            abi.encodePacked(_report.strategy, _report.nonce, _chainId)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        require(
            ECDSA.recover(ethSignedMessageHash, _report.signature) ==
                strategies[_chainId][_report.strategy].strategist,
            "V23"
        );

        _usedNonces[_chainId][_report.strategy][_report.nonce] = true;
    }

    receive() external payable {}
}
