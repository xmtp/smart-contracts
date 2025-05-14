// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";
import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IERC20InboxLike, IAppChainGatewayLike, IParameterRegistryLike } from "./interfaces/External.sol";
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
    function depositSenderFunds(address inbox_, uint256 amount_) external {
        _redirectFunds(inbox_, amount_);

        uint256 messageNumber_ = IERC20InboxLike(inbox_).depositERC20(amount_);

        // slither-disable-next-line reentrancy-events
        emit SenderFundsDeposited(inbox_, messageNumber_, amount_);
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParameters(
        address[] calldata inboxes_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external {
        if (inboxes_.length == 0) revert NoInboxes();

        uint256 nonce_;

        unchecked {
            nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        }

        bytes memory data_ = _getEncodedParameters(nonce_, keys_);

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            // TODO: Should `_redirectFunds` be called here? If so, consider re-entrancy prevention.

            // slither-disable-next-line calls-loop
            uint256 messageNumber_ = IERC20InboxLike(inboxes_[index_]).sendContractTransaction({
                gasLimit_: gasLimit_,
                maxFeePerGas_: gasPrice_,
                to_: appChainGateway,
                value_: 0,
                data_: data_
            });

            // slither-disable-next-line reentrancy-events
            emit ParametersSent(inboxes_[index_], messageNumber_, nonce_, keys_);
        }
    }

    /// @inheritdoc ISettlementChainGateway
    function sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external {
        if (inboxes_.length == 0) revert NoInboxes();

        uint256 nonce_;

        unchecked {
            nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        }

        bytes memory data_ = _getEncodedParameters(nonce_, keys_);
        address appChainAlias_ = appChainAlias();

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            _redirectFunds(inboxes_[index_], nativeTokensToSend_); // TODO: Consider re-entrancy prevention.

            // slither-disable-next-line calls-loop
            uint256 messageNumber_ = IERC20InboxLike(inboxes_[index_]).createRetryableTicket({
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
            emit ParametersSent(inboxes_[index_], messageNumber_, nonce_, keys_);
        }
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc ISettlementChainGateway
    function appChainAlias() public view returns (address alias_) {
        return AddressAliasHelper.applyL1ToL2Alias(address(this));
    }

    /// @inheritdoc ISettlementChainGateway
    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.settlementChainGateway.migrator";
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Pulls and amount of tokens from the caller, and approves some inbox to spend them.
    function _redirectFunds(address inbox_, uint256 amount_) internal {
        SafeTransferLib.safeTransferFrom(appChainNativeToken, msg.sender, address(this), amount_);
        SafeTransferLib.safeApprove(appChainNativeToken, inbox_, amount_);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

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
                (nonce_, keys_, IParameterRegistryLike(parameterRegistry).get(keys_))
            );
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }
}
