// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";
import { ERC20Helper } from "../../lib/erc20-helper/src/ERC20Helper.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IERC20InboxLike, IAppChainGatewayLike, IParameterRegistryLike } from "./interfaces/External.sol";
import { ISettlementChainGateway } from "./interfaces/ISettlementChainGateway.sol";

import { Migratable } from "../abstract/Migratable.sol";

contract SettlementChainGateway is ISettlementChainGateway, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    address public immutable registry;
    address public immutable appChainGateway;
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

    constructor(address registry_, address appChainGateway_, address appChainNativeToken_) {
        require(_isNotZero(registry = registry_), ZeroRegistryAddress());
        require(_isNotZero(appChainGateway = appChainGateway_), ZeroAppChainGatewayAddress());
        require(_isNotZero(appChainNativeToken = appChainNativeToken_), ZeroAppChainNativeTokenAddress());
    }

    /* ============ Initialization ============ */

    function initialize() external initializer {
        // TODO: If nothing to initialize, consider `_disableInitializers()` in constructor.
    }

    /* ============ Interactive Functions ============ */

    function depositSenderFunds(address inbox_, uint256 amount_) external {
        require(ERC20Helper.transferFrom(appChainNativeToken, msg.sender, address(this), amount_), TransferFailed());
        require(ERC20Helper.approve(appChainNativeToken, inbox_, amount_), ApproveFailed());

        uint256 messageNumber_ = IERC20InboxLike(inbox_).depositERC20(amount_);

        emit SenderFundsDeposited(inbox_, messageNumber_, amount_);
    }

    function sendParameters(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external {
        require(inboxes_.length > 0, NoInboxes());

        uint256 nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        bytes memory data_ = _getEncodedParameters(nonce_, keyChains_);

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            uint256 messageNumber_ = IERC20InboxLike(inboxes_[index_]).sendContractTransaction({
                gasLimit_: gasLimit_,
                maxFeePerGas_: gasPrice_,
                to_: appChainGateway,
                value_: 0,
                data_: data_
            });

            emit ParametersSent(inboxes_[index_], messageNumber_, nonce_, keyChains_);
        }
    }

    function sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external {
        require(inboxes_.length > 0, NoInboxes());

        uint256 nonce_ = ++_getSettlementChainGatewayStorage().nonce;
        bytes memory data_ = _getEncodedParameters(nonce_, keyChains_);
        address appChainAlias_ = appChainAlias();

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
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

            emit ParametersSent(inboxes_[index_], messageNumber_, nonce_, keyChains_);
        }
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
    }

    /* ============ View/Pure Functions ============ */

    function appChainAlias() public view returns (address alias_) {
        return AddressAliasHelper.applyL1ToL2Alias(address(this));
    }

    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.scg.migrator";
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        bytes[] memory keyChain_ = new bytes[](1);
        keyChain_[0] = key_;

        return IParameterRegistryLike(registry).get(keyChain_);
    }

    function _getEncodedParameters(
        uint256 nonce_,
        bytes[][] calldata keyChains_
    ) internal view returns (bytes memory encoded_) {
        require(keyChains_.length > 0, NoKeyChains());

        return
            abi.encodeCall(
                IAppChainGatewayLike.receiveParameters,
                (nonce_, keyChains_, IParameterRegistryLike(registry).get(keyChains_))
            );
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        isNotZero_ = input_ != address(0);
    }
}
