// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../libraries/AddressAliasHelper.sol";
import { ParameterKeys } from "../libraries/ParameterKeys.sol";
import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IAppChainGatewayLike, IERC20InboxLike } from "./interfaces/External.sol";
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
    address public immutable appChainNativeToken;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.SettlementChainGateway
     * @notice The UUPS storage for the settlement chain gateway.
     * @param  nonce The nonce of the parameter transmission (to prevent out-of-sequence resets).
     */
    struct SettlementChainGatewayStorage {
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

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_   The address of the parameter registry.
     * @param  appChainGateway_     The address of the app chain gateway.
     * @param  appChainNativeToken_ The address of the token on the settlement chain that is used as native gas token on
     *                              the app chain.
     * @dev    The parameter registry, app chain gateway, and app chain native token must not be the zero address.
     * @dev    The parameter registry, app chain gateway, and app chain native token are immutable so that they are
     *         inlined in the contract code, and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address appChainGateway_, address appChainNativeToken_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(appChainGateway = appChainGateway_)) revert ZeroAppChainGateway();
        if (_isZero(appChainNativeToken = appChainNativeToken_)) revert ZeroAppChainNativeToken();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc ISettlementChainGateway
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function depositSenderFunds(uint256 chainId_, uint256 amount_) external {
        address inbox_ = _getInbox(chainId_);

        _redirectFunds(inbox_, amount_);

        uint256 messageNumber_ = IERC20InboxLike(inbox_).depositERC20(amount_);

        // slither-disable-next-line reentrancy-events
        emit SenderFundsDeposited(chainId_, inbox_, messageNumber_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParameters(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external {
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
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external {
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
                maxSubmissionCost_: maxSubmissionCost_,
                nativeTokensToSend_: nativeTokensToSend_,
                data_: data_,
                nonce_: nonce_,
                appChainAlias_: appChainAlias_
            });
        }
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

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
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
    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.settlementChainGateway.migrator";
    }

    /// @inheritdoc ISettlementChainGateway
    function getInbox(uint256 chainId_) external view returns (address inbox_) {
        return _getInbox(chainId_);
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Pulls and amount of tokens from the caller, and approves some inbox to spend them.
    function _redirectFunds(address inbox_, uint256 amount_) internal {
        SafeTransferLib.safeTransferFrom(appChainNativeToken, msg.sender, address(this), amount_);
        SafeTransferLib.safeApprove(appChainNativeToken, inbox_, amount_);
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

    /// @dev Sends parameters to the app chain via a retryable ticket.
    function _sendParametersAsRetryableTicket(
        uint256 chainId_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_,
        bytes memory data_,
        uint256 nonce_,
        address appChainAlias_
    ) internal {
        address inbox_ = _getInbox(chainId_);

        _redirectFunds(inbox_, nativeTokensToSend_);

        // slither-disable-next-line calls-loop
        uint256 messageNumber_ = IERC20InboxLike(inbox_).createRetryableTicket({
            to_: appChainGateway,
            l2CallValue_: 0,
            maxSubmissionCost_: maxSubmissionCost_,
            excessFeeRefundAddress_: appChainAlias_,
            callValueRefundAddress_: appChainAlias_,
            gasLimit_: gasLimit_,
            maxFeePerGas_: gasPrice_,
            tokenTotalFeeAmount_: nativeTokensToSend_,
            data_: data_
        });

        // slither-disable-next-line reentrancy-events
        emit ParametersSent(chainId_, inbox_, messageNumber_, nonce_, keys_);
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
}
