// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";
import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IERC20InboxLike, IAppChainGatewayLike, IParameterRegistryLike } from "./interfaces/External.sol";
import { ISettlementChainGateway } from "./interfaces/ISettlementChainGateway.sol";

import { Migratable } from "../abstract/Migratable.sol";

contract SettlementChainGateway is ISettlementChainGateway, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc ISettlementChainGateway
    address public immutable parameterRegistry;

    /// @inheritdoc ISettlementChainGateway
    address public immutable appChainGateway;

    /// @inheritdoc ISettlementChainGateway
    address public immutable appChainNativeToken;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.SettlementChainGateway
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
     * @notice Constructor.
     * @param  parameterRegistry_   The address of the parameter registry.
     * @param  appChainGateway_     The address of the app chain gateway.
     * @param  appChainNativeToken_ The address of the token on the settlement chain that is used as native gas token on
     *                              the app chain.
     */
    constructor(address parameterRegistry_, address appChainGateway_, address appChainNativeToken_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
        require(_isNotZero(appChainGateway = appChainGateway_), ZeroAppChainGatewayAddress());
        require(_isNotZero(appChainNativeToken = appChainNativeToken_), ZeroAppChainNativeTokenAddress());

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
        require(inboxes_.length > 0, NoInboxes());

        uint256 nonce_ = ++_getSettlementChainGatewayStorage().nonce;
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
        require(inboxes_.length > 0, NoInboxes());

        uint256 nonce_ = ++_getSettlementChainGatewayStorage().nonce;
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
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
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

    function _redirectFunds(address inbox_, uint256 amount_) internal {
        SafeTransferLib.safeTransferFrom(appChainNativeToken, msg.sender, address(this), amount_);
        SafeTransferLib.safeApprove(appChainNativeToken, inbox_, amount_);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _getEncodedParameters(
        uint256 nonce_,
        bytes[] calldata keys_
    ) internal view returns (bytes memory encoded_) {
        require(keys_.length > 0, NoKeys());

        return
            abi.encodeCall(
                IAppChainGatewayLike.receiveParameters,
                (nonce_, keys_, IParameterRegistryLike(parameterRegistry).get(keys_))
            );
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }
}
