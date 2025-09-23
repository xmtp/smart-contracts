// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../libraries/AddressAliasHelper.sol";
import { ParameterKeys } from "../libraries/ParameterKeys.sol";
import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import {
    IAppChainGatewayLike,
    IERC20InboxLike,
    IERC20Like,
    IFeeTokenLike,
    IPermitErc20Like
} from "./interfaces/External.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { ISettlementChainGateway } from "./interfaces/ISettlementChainGateway.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation for a Settlement Chain Gateway.
 * @notice A SettlementChainGateway exposes the ability to send parameters to any app chain gateways, via their
 *         respective inboxes on the settlement chain.
 */
contract SettlementChainGateway is ISettlementChainGateway, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc ISettlementChainGateway
    address public immutable parameterRegistry;

    /// @inheritdoc ISettlementChainGateway
    address public immutable appChainGateway;

    /// @inheritdoc ISettlementChainGateway
    address public immutable feeToken;

    /// @dev The address of the token underlying the fee token.
    address internal immutable _underlyingFeeToken;

    /// @dev The number of decimals of the fee token.
    uint8 internal immutable _feeTokenDecimals;

    /// @dev The length of the submission data for the `receiveDeposit` call to the app chain gateway.
    uint256 internal immutable _receiveDepositDataLength;

    /// @dev The precomputed scaling factor between the fee token's decimals and 18 decimals (wei).
    uint256 internal immutable _scale;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.SettlementChainGateway
     * @notice The UUPS storage for the settlement chain gateway.
     * @param  nonce The nonce of the parameter transmission (to prevent out-of-sequence resets).
     */
    struct SettlementChainGatewayStorage {
        bool paused;
        uint256 nonce;
        mapping(uint256 chainId => address inbox) inboxes;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.SettlementChainGateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _SETTLEMENT_CHAIN_GATEWAY_STORAGE_LOCATION =
        0xa66588577d68bb28d3fa2c7238607341f39141e4eaf5f706037ae5c1c2a15700;

    function _getSettlementChainGatewayStorage() internal pure returns (SettlementChainGatewayStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _SETTLEMENT_CHAIN_GATEWAY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @param  appChainGateway_   The address of the app chain gateway.
     * @param  feeToken_          The address of the fee token on the settlement chain, that is used to pay for gas on
     *                            app chains.
     * @dev    The parameter registry, app chain gateway, and fee token must not be the zero address.
     * @dev    The parameter registry, app chain gateway, and fee token are immutable so that they are
     *         inlined in the contract code, and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address appChainGateway_, address feeToken_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(appChainGateway = appChainGateway_)) revert ZeroAppChainGateway();
        if (_isZero(feeToken = feeToken_)) revert ZeroFeeToken();

        _feeTokenDecimals = IERC20Like(feeToken).decimals();

        if (_feeTokenDecimals > 18) revert InvalidFeeTokenDecimals();

        _scale = 10 ** (18 - _feeTokenDecimals);

        _underlyingFeeToken = IFeeTokenLike(feeToken).underlying();

        _receiveDepositDataLength = abi.encodeCall(IAppChainGatewayLike.receiveDeposit, address(0)).length;

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc ISettlementChainGateway
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function deposit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_
    ) external whenNotPaused {
        _depositFeeToken(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositWithPermit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused {
        _usePermit(feeToken, amount_, deadline_, v_, r_, s_);
        _depositFeeToken(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositFromUnderlying(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_
    ) external whenNotPaused {
        _depositFromUnderlying(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositFromUnderlyingWithPermit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused {
        // NOTE: There is no issue if the underlying fee token permit use results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy. Further, the permit must be used before being
        //       able to pull any underlying fee tokens from the caller.
        _usePermit(_underlyingFeeToken, amount_, deadline_, v_, r_, s_);
        _depositFromUnderlying(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParameters(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_
    ) external whenNotPaused returns (uint256 totalSent_) {
        return _sendParametersFromFeeToken(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersWithPermit(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused returns (uint256 totalSent_) {
        _usePermit(feeToken, amountToSend_ * chainIds_.length, deadline_, v_, r_, s_);

        return _sendParametersFromFeeToken(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersFromUnderlying(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_
    ) external whenNotPaused returns (uint256 totalSent_) {
        return _sendParametersFromUnderlying(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersFromUnderlyingWithPermit(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused returns (uint256 totalSent_) {
        // NOTE: There is no issue if the underlying fee token permit use results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy. Further, the permit must be used before being
        //       able to pull any underlying fee tokens from the caller.
        _usePermit(_underlyingFeeToken, amountToSend_ * chainIds_.length, deadline_, v_, r_, s_);

        return _sendParametersFromUnderlying(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function updateInbox(uint256 chainId_) external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        address inbox_ = RegistryParameters.getAddressParameter(
            parameterRegistry,
            _getInboxKey(inboxParameterKey(), chainId_)
        );

        // NOTE: `address(0)` is valid, as it disables the inbox for a chain ID.
        emit InboxUpdated(chainId_, _getSettlementChainGatewayStorage().inboxes[chainId_] = inbox_);
    }

    /// @inheritdoc ISettlementChainGateway
    function updatePauseStatus() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        bool paused_ = RegistryParameters.getBoolParameter(parameterRegistry, pausedParameterKey());
        SettlementChainGatewayStorage storage $ = _getSettlementChainGatewayStorage();

        if (paused_ == $.paused) revert NoChange();

        emit PauseStatusUpdated($.paused = paused_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /// @inheritdoc ISettlementChainGateway
    function receiveWithdrawal(address recipient_) external returns (uint256 amount_) {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transfer(recipient_, amount_ = _prepareWithdrawal(recipient_));
    }

    /// @inheritdoc ISettlementChainGateway
    function receiveWithdrawalIntoUnderlying(address recipient_) external returns (uint256 amount_) {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unused-return
        IFeeTokenLike(feeToken).withdrawTo(recipient_, amount_ = _prepareWithdrawal(recipient_));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function appChainAlias() public view returns (address alias_) {
        return AddressAliasHelper.toAlias(address(this));
    }

    /// @inheritdoc ISettlementChainGateway
    function inboxParameterKey() public pure returns (string memory key_) {
        return "xmtp.settlementChainGateway.inbox";
    }

    /// @inheritdoc ISettlementChainGateway
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.settlementChainGateway.migrator";
    }

    /// @inheritdoc ISettlementChainGateway
    function pausedParameterKey() public pure returns (string memory key_) {
        return "xmtp.settlementChainGateway.paused";
    }

    /// @inheritdoc ISettlementChainGateway
    function paused() external view returns (bool paused_) {
        return _getSettlementChainGatewayStorage().paused;
    }

    /// @inheritdoc ISettlementChainGateway
    function calculateMaxDepositFee(
        uint256 chainId_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 maxBaseFee_
    ) external view returns (uint256 fees_) {
        (uint256 maxSubmissionCost_, uint256 maxTransactionCost_) = _calculateMaxCosts(
            _getInbox(chainId_),
            _receiveDepositDataLength,
            gasLimit_,
            maxFeePerGas_,
            maxBaseFee_
        );

        return maxSubmissionCost_ + maxTransactionCost_;
    }

    /// @inheritdoc ISettlementChainGateway
    function getInbox(uint256 chainId_) external view returns (address inbox_) {
        return _getInbox(chainId_);
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Transfers `amount_` of fee tokens from the caller to this contract to satisfy a deposit to an app chain.
    function _depositFeeToken(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_
    ) internal {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IERC20Like(feeToken).transferFrom` nor `_deposit` can result in a reentrancy.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), amount_);
        _deposit(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /**
     * @dev Transfers `amount_` of underlying fee tokens from the caller to this contract to satisfy a deposit to an app
     *      chain.
     */
    function _depositFromUnderlying(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_
    ) internal {
        // NOTE: There is no issue if the underlying fee token transfer results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IFeeTokenLike(feeToken).deposit` nor `_deposit` can result in a reentrancy.
        _pullAndConvertUnderlying(amount_);
        _deposit(chainId_, recipient_, amount_, gasLimit_, maxFeePerGas_);
    }

    /// @dev Deposits fee tokens into an inbox, to be used as native gas token on the app chain.
    function _deposit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_
    ) internal {
        address inbox_ = _getInbox(chainId_);

        if (_isZero(recipient_)) revert ZeroRecipient();

        if (amount_ == 0) revert ZeroAmount();

        bytes memory data_ = abi.encodeCall(IAppChainGatewayLike.receiveDeposit, (recipient_));

        (uint256 maxSubmissionCost_, uint256 maxTransactionCost_) = _calculateMaxCosts(
            inbox_,
            data_.length,
            gasLimit_,
            maxFeePerGas_,
            block.basefee
        );

        uint256 appChainAmount_ = _convertToWei(amount_);
        uint256 maxTotalCosts_ = maxSubmissionCost_ + maxTransactionCost_;

        if (appChainAmount_ < maxTotalCosts_) revert InsufficientAmount(appChainAmount_, maxTotalCosts_);

        uint256 messageNumber_ = _createRetryableTicket({
            inbox_: inbox_,
            callValue_: appChainAmount_ - maxTotalCosts_,
            maxSubmissionCost_: maxSubmissionCost_,
            gasLimit_: gasLimit_,
            maxFeePerGas_: maxFeePerGas_,
            feeTokenAmount_: amount_,
            data_: data_
        });

        // slither-disable-next-line reentrancy-events
        emit Deposit(chainId_, messageNumber_, recipient_, amount_);
    }

    /// @dev Pull the underlying fee tokens from the caller, and convert them to fee tokens.
    function _pullAndConvertUnderlying(uint256 amount_) internal {
        SafeTransferLib.safeTransferFrom(_underlyingFeeToken, msg.sender, address(this), amount_);
        IFeeTokenLike(feeToken).deposit(amount_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets, pulling fee tokens from the caller.
    function _sendParametersFromFeeToken(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_
    ) internal returns (uint256 totalSent_) {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IERC20Like(feeToken).transferFrom` nor `_sendParameters` can result in a
        //       reentrancy.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), totalSent_ = amountToSend_ * chainIds_.length);

        _sendParameters(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets, pulling underlying fee tokens from the caller.
    function _sendParametersFromUnderlying(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_
    ) internal returns (uint256 totalSent_) {
        // NOTE: There is no issue if the underlying fee token transfer results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IFeeTokenLike(feeToken).deposit` nor `_sendParameters` can result in a
        //       reentrancy.
        _pullAndConvertUnderlying(totalSent_ = amountToSend_ * chainIds_.length);

        _sendParameters(chainIds_, keys_, gasLimit_, maxFeePerGas_, amountToSend_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets.
    function _sendParameters(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 amountToSend_
    ) internal {
        if (chainIds_.length == 0) revert NoChainIds();

        uint256 nonce_;

        unchecked {
            nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        }

        if (keys_.length == 0) revert NoKeys();

        bytes memory data_ = abi.encodeCall(
            IAppChainGatewayLike.receiveParameters,
            (nonce_, keys_, RegistryParameters.getRegistryParameters(parameterRegistry, keys_))
        );

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            address inbox_ = _getInbox(chainIds_[index_]);

            (uint256 maxSubmissionCost_, ) = _calculateMaxCosts(
                inbox_,
                data_.length,
                gasLimit_,
                maxFeePerGas_,
                block.basefee
            );

            uint256 messageNumber_ = _createRetryableTicket({
                inbox_: inbox_,
                callValue_: 0,
                maxSubmissionCost_: maxSubmissionCost_,
                gasLimit_: gasLimit_,
                maxFeePerGas_: maxFeePerGas_,
                feeTokenAmount_: amountToSend_,
                data_: data_
            });

            // slither-disable-next-line reentrancy-events
            emit ParametersSent(chainIds_[index_], messageNumber_, nonce_, keys_);
        }
    }

    /**
     * @dev    Creates a retryable ticket, via the inbox, to perform a call to the app chain gateway (on the app chain).
     * @param  inbox_             The inbox via which to create a retryable ticket.
     * @param  callValue_         The call value (18 decimals) to send with the call to the app chain gateway.
     * @param  maxSubmissionCost_ The maximum submission cost (18 decimals) for the retryable ticket.
     * @param  gasLimit_          The gas limit for the call to the app chain gateway.
     * @param  maxFeePerGas_      The maximum fee per gas (EIP-1559) for the call to the app chain gateway.
     * @param  feeTokenAmount_    The total fee tokens (fee token decimals) that should be pulled by the inbox.
     * @param  data_              The data to call to call the app chain gateway with.
     * @return messageNumber_     The message number of the retryable ticket.
     * @dev    `feeTokenAmount_` (converted to 18 decimals) must be greater or equal to
     *         `maxSubmissionCost_ + callValue_ + (gasLimit_ * maxFeePerGas_)`
     */
    function _createRetryableTicket(
        address inbox_,
        uint256 callValue_,
        uint256 maxSubmissionCost_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 feeTokenAmount_,
        bytes memory data_
    ) internal returns (uint256 messageNumber_) {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-start calls-loop
        // slither-disable-next-line unused-return
        IERC20Like(feeToken).approve(inbox_, feeTokenAmount_);

        address appChainAlias_ = appChainAlias();

        // NOTE: No need to validate `gasLimit_` and/or `maxFeePerGas_` since the purpose of retryable tickets are to
        //       allow the gas parameters to be modified and the ticket retried on the app chain later, if needed.
        //       Further, `IERC20InboxLike.createRetryableTicket` already does some sanity checks.
        messageNumber_ = IERC20InboxLike(inbox_).createRetryableTicket({
            to_: appChainGateway,
            l2CallValue_: callValue_,
            maxSubmissionCost_: maxSubmissionCost_,
            excessFeeRefundAddress_: appChainAlias_,
            callValueRefundAddress_: appChainAlias_,
            gasLimit_: gasLimit_,
            maxFeePerGas_: maxFeePerGas_,
            tokenTotalFeeAmount_: feeTokenAmount_,
            data_: data_
        });
        // slither-disable-end calls-loop
    }

    /**
     * @dev Uses a permit to approve the deposit of `amount_` of `token_` from the caller to this contract.
     * @dev Silently ignore a failing permit, as it may indicate that the permit was already used and/or the allowance
     *      has already been approved.
     */
    function _usePermit(address token_, uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) internal {
        // Ignore return value, as the permit may have already been used, and the allowance already approved.
        // slither-disable-next-line unchecked-lowlevel
        address(token_).call(
            abi.encodeWithSelector(
                IPermitErc20Like.permit.selector,
                msg.sender,
                address(this),
                amount_,
                deadline_,
                v_,
                r_,
                s_
            )
        );
    }

    /// @dev Prepares a withdrawal of fee tokens by querying the available balance and emitting an event.
    function _prepareWithdrawal(address recipient_) internal returns (uint256 amount_) {
        // NOTE: It's safe to just send/withdraw the balance, without access controls or balance validation, since this
        //       contract should only hold fee tokens if it was sent them right before this function is called. To be
        //       more clear, a user has already instructed the ArbSys bridge on an app chain to `sendTxToL1` with the
        //       call data of `withdrawIntoUnderlying(someAccount)`, so the Outbox will send the fee tokens to this
        //       contract and then immediately execute that call data to unwrap the fee tokens to `someAccount`.
        amount_ = IERC20Like(feeToken).balanceOf(address(this));

        emit WithdrawalReceived(recipient_, amount_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Calculates the total fees to submit a retryable ticket and call the app chain gateway on the app chain.
     * @param  inbox_              The inbox to the app chain.
     * @param  dataLength_         The length of the call data to send to the app chain.
     * @param  gasLimit_           The gas limit for the call on the app chain.
     * @param  maxFeePerGas_       The maximum fee per gas (EIP-1559) for the call on the app chain.
     * @param  maxBaseFee_         The maximum base fee of the settlement chain, in wei (18 decimals).
     * @return maxSubmissionCost_  The maximum submission cost for the retryable ticket, in wei (18 decimals).
     * @return maxTransactionCost_ The maximum transaction cost for the call on the app chain, in wei (18 decimals).
     */
    function _calculateMaxCosts(
        address inbox_,
        uint256 dataLength_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 maxBaseFee_
    ) internal view returns (uint256 maxSubmissionCost_, uint256 maxTransactionCost_) {
        maxSubmissionCost_ = IERC20InboxLike(inbox_).calculateRetryableSubmissionFee(dataLength_, maxBaseFee_);
        maxTransactionCost_ = maxFeePerGas_ * gasLimit_;
    }

    function _convertToWei(uint256 value_) internal view returns (uint256 wei_) {
        return value_ * _scale;
    }

    /**
     * @dev Returns the inbox-specific key used to query to parameter registry to determine the inbox for a chain ID.
     *      The inbox-specific key is the concatenation of the inbox parameter key and the chain ID.
     *      For example, if the inbox parameter key is "xmtp.settlementChainGateway.inbox", then the key for chain ID
     *      1 is "xmtp.settlementChainGateway.inbox.1".
     */
    function _getInboxKey(
        string memory inboxParameterKey_,
        uint256 chainId_
    ) internal pure returns (string memory key_) {
        return ParameterKeys.combineKeyComponents(inboxParameterKey_, ParameterKeys.uint256ToKeyComponent(chainId_));
    }

    function _getInbox(uint256 chainId_) internal view returns (address inbox_) {
        inbox_ = _getSettlementChainGatewayStorage().inboxes[chainId_];

        if (_isZero(inbox_)) revert UnsupportedChainId(chainId_);
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfPaused() internal view {
        if (_getSettlementChainGatewayStorage().paused) revert Paused();
    }
}
