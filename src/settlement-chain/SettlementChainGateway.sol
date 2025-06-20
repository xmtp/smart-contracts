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

        _underlyingFeeToken = IFeeTokenLike(feeToken).underlying();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc ISettlementChainGateway
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function deposit(uint256 chainId_, uint256 amount_) external whenNotPaused {
        _depositFeeToken(chainId_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositWithPermit(
        uint256 chainId_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused {
        _usePermit(feeToken, amount_, deadline_, v_, r_, s_);
        _depositFeeToken(chainId_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositFromUnderlying(uint256 chainId_, uint256 amount_) external whenNotPaused {
        _depositFromUnderlying(chainId_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function depositFromUnderlyingWithPermit(
        uint256 chainId_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused {
        _usePermit(_underlyingFeeToken, amount_, deadline_, v_, r_, s_);
        _depositFromUnderlying(chainId_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParameters(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external whenNotPaused {
        if (chainIds_.length == 0) revert NoChainIds();

        uint256 nonce_;

        unchecked {
            nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        }

        bytes memory data_ = _getEncodedParameters(nonce_, keys_);

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            _sendParameters(chainIds_[index_], keys_, gasLimit_, gasPrice_, data_, nonce_);
        }
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersAsRetryableTickets(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) external whenNotPaused returns (uint256 totalSent_) {
        return _sendParametersAsRetryableTicketsFromFeeToken(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersAsRetryableTicketsWithPermit(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused returns (uint256 totalSent_) {
        _usePermit(feeToken, amountToSend_ * chainIds_.length, deadline_, v_, r_, s_);

        return _sendParametersAsRetryableTicketsFromFeeToken(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersAsRetryableTicketsFromUnderlying(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) external whenNotPaused returns (uint256 totalSent_) {
        return _sendParametersAsRetryableTicketsFromUnderlying(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersAsRetryableTicketsFromUnderlyingWithPermit(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external whenNotPaused returns (uint256 totalSent_) {
        _usePermit(_underlyingFeeToken, amountToSend_ * chainIds_.length, deadline_, v_, r_, s_);

        return _sendParametersAsRetryableTicketsFromUnderlying(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @inheritdoc ISettlementChainGateway
    function updateInbox(uint256 chainId_) external {
        address inbox_ = RegistryParameters.getAddressParameter(
            parameterRegistry,
            _getInboxKey(inboxParameterKey(), chainId_)
        );

        // NOTE: `address(0)` is valid, as it disables the inbox for a chain ID.
        emit InboxUpdated(chainId_, _getSettlementChainGatewayStorage().inboxes[chainId_] = inbox_);
    }

    /// @inheritdoc ISettlementChainGateway
    function updatePauseStatus() external {
        bool paused_ = RegistryParameters.getBoolParameter(parameterRegistry, pausedParameterKey());
        SettlementChainGatewayStorage storage $ = _getSettlementChainGatewayStorage();

        if (paused_ == $.paused) revert NoChange();

        emit PauseStatusUpdated($.paused = paused_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /// @inheritdoc ISettlementChainGateway
    function withdraw(address recipient_) external returns (uint256 amount_) {
        // NOTE: It is safe to just send/withdraw the the balance, as this contract should only hold fee tokens if it
        //       was sent them right before this function is called.
        amount_ = IERC20Like(feeToken).balanceOf(address(this));

        emit Withdrawal(amount_, recipient_);

        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transfer(recipient_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function withdrawIntoUnderlying(address recipient_) external returns (uint256 amount_) {
        // NOTE: It is safe to just send/withdraw the the balance, as this contract should only hold fee tokens if it
        //       was sent them right before this function is called.
        amount_ = IERC20Like(feeToken).balanceOf(address(this));

        emit Withdrawal(amount_, recipient_);

        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unused-return
        IFeeTokenLike(feeToken).withdrawTo(recipient_, amount_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function appChainAlias() public view returns (address alias_) {
        return AddressAliasHelper.toAlias(address(this));
    }

    /// @inheritdoc ISettlementChainGateway
    function inboxParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.settlementChainGateway.inbox";
    }

    /// @inheritdoc ISettlementChainGateway
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.settlementChainGateway.migrator";
    }

    /// @inheritdoc ISettlementChainGateway
    function pausedParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.settlementChainGateway.paused";
    }

    /// @inheritdoc ISettlementChainGateway
    function paused() external view returns (bool paused_) {
        return _getSettlementChainGatewayStorage().paused;
    }

    /// @inheritdoc ISettlementChainGateway
    function getInbox(uint256 chainId_) external view returns (address inbox_) {
        return _getInbox(chainId_);
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Transfers `amount_` of fee tokens from the caller to this contract to satisfy a deposit to an app chain.
    function _depositFeeToken(uint256 chainId_, uint256 amount_) internal {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), amount_);
        _deposit(chainId_, amount_);
    }

    /**
     * @dev Transfers `amount_` of underlying fee tokens from the caller to this contract to satisfy a deposit to an app
     *      chain.
     */
    function _depositFromUnderlying(uint256 chainId_, uint256 amount_) internal {
        _pullAndConvertUnderlying(amount_);
        _deposit(chainId_, amount_);
    }

    /// @dev Deposits fee tokens into an inbox, to be used as native gas token on the app chain.
    function _deposit(uint256 chainId_, uint256 amount_) internal {
        address inbox_ = _getInbox(chainId_);

        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unused-return
        IERC20Like(feeToken).approve(inbox_, amount_);

        uint256 messageNumber_ = IERC20InboxLike(inbox_).depositERC20(amount_);

        // slither-disable-next-line reentrancy-events
        emit Deposit(chainId_, inbox_, messageNumber_, amount_);
    }

    /// @dev Pull the underlying fee tokens from the caller, and convert them to fee tokens.
    function _pullAndConvertUnderlying(uint256 amount_) internal {
        SafeTransferLib.safeTransferFrom(_underlyingFeeToken, msg.sender, address(this), amount_);
        IFeeTokenLike(feeToken).deposit(amount_);
    }

    /// @dev Sends parameters to the app chain via a contract transaction.
    function _sendParameters(
        uint256 chainId_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        bytes memory data_,
        uint256 nonce_
    ) internal {
        address inbox_ = _getInbox(chainId_);

        // slither-disable-next-line calls-loop
        uint256 messageNumber_ = IERC20InboxLike(inbox_).sendContractTransaction({
            gasLimit_: gasLimit_,
            maxFeePerGas_: gasPrice_,
            to_: appChainGateway,
            value_: 0,
            data_: data_
        });

        // slither-disable-next-line reentrancy-events
        emit ParametersSent(chainId_, inbox_, messageNumber_, nonce_, keys_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets, pulling fee tokens from the caller.
    function _sendParametersAsRetryableTicketsFromFeeToken(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) internal returns (uint256 totalSent_) {
        // Pull the fee tokens from the caller.
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), totalSent_ = amountToSend_ * chainIds_.length);

        _sendParametersAsRetryableTickets(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets, pulling underlying fee tokens from the caller.
    function _sendParametersAsRetryableTicketsFromUnderlying(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) internal returns (uint256 totalSent_) {
        _pullAndConvertUnderlying(totalSent_ = amountToSend_ * chainIds_.length);

        _sendParametersAsRetryableTickets(chainIds_, keys_, gasLimit_, gasPrice_, amountToSend_);
    }

    /// @dev Sends parameters to the app chains via a retryable tickets.
    function _sendParametersAsRetryableTickets(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) internal {
        if (chainIds_.length == 0) revert NoChainIds();

        uint256 nonce_;

        unchecked {
            nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        }

        bytes memory data_ = _getEncodedParameters(nonce_, keys_);
        address appChainAlias_ = appChainAlias();

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            _sendParametersAsRetryableTicket({
                chainId_: chainIds_[index_],
                keys_: keys_,
                gasLimit_: gasLimit_,
                gasPrice_: gasPrice_,
                feeTokensToSend_: amountToSend_,
                data_: data_,
                nonce_: nonce_,
                appChainAlias_: appChainAlias_
            });
        }
    }

    /// @dev Sends parameters to the app chain via a retryable ticket.
    function _sendParametersAsRetryableTicket(
        uint256 chainId_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 feeTokensToSend_,
        bytes memory data_,
        uint256 nonce_,
        address appChainAlias_
    ) internal {
        address inbox_ = _getInbox(chainId_);

        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-start calls-loop
        // slither-disable-next-line unused-return
        IERC20Like(feeToken).approve(inbox_, feeTokensToSend_);

        uint256 messageNumber_ = IERC20InboxLike(inbox_).createRetryableTicket({
            to_: appChainGateway,
            l2CallValue_: 0,
            maxSubmissionCost_: 0,
            excessFeeRefundAddress_: appChainAlias_,
            callValueRefundAddress_: appChainAlias_,
            gasLimit_: gasLimit_,
            maxFeePerGas_: gasPrice_,
            tokenTotalFeeAmount_: feeTokensToSend_,
            data_: data_
        });
        // slither-disable-end calls-loop

        // slither-disable-next-line reentrancy-events
        emit ParametersSent(chainId_, inbox_, messageNumber_, nonce_, keys_);
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

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Encodes the parameters and their values, from the settlement chain parameter registry, as a batch to be
     *      sent to the app chain. The function to be called on the app chain is `IAppChainGateway.receiveParameters`.
     */
    function _getEncodedParameters(
        uint256 nonce_,
        bytes[] calldata keys_
    ) internal view returns (bytes memory encoded_) {
        if (keys_.length == 0) revert NoKeys();

        return
            abi.encodeCall(
                IAppChainGatewayLike.receiveParameters,
                (nonce_, keys_, RegistryParameters.getRegistryParameters(parameterRegistry, keys_))
            );
    }

    /**
     * @dev Returns the inbox-specific key used to query to parameter registry to determine the inbox for a chain ID.
     *      The inbox-specific key is the concatenation of the inbox parameter key and the chain ID.
     *      For example, if the inbox parameter key is "xmtp.settlementChainGateway.inbox", then the key for chain ID
     *      1 is "xmtp.settlementChainGateway.inbox.1".
     */
    function _getInboxKey(bytes memory inboxParameterKey_, uint256 chainId_) internal pure returns (bytes memory key_) {
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
