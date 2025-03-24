// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "../../lib/oz-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { ERC20Helper } from "../../lib/erc20-helper/src/ERC20Helper.sol";

import { IERC20InboxLike, IAppchainGatewayLike, IParameterRegistry } from "./interfaces/External.sol";
import { ISettlementGateway } from "./interfaces/ISettlementGateway.sol";

// TODO: Message ordering.
// TODO: Admin set/reset and event.

contract SettlementGateway is ISettlementGateway, Initializable, UUPSUpgradeable {
    /* ============ Constants ============ */

    address public immutable registry;
    address public immutable appchainGateway;
    address public immutable appchainAlias;
    address public immutable appchainNativeToken;

    /* ============ Storage ============ */

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.SettlementGateway
    struct SettlementGatewayStorage {
        address admin;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.SettlementGateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _SETTLEMENT_GATEWAY_STORAGE_LOCATION =
        0x97179c306b839206d96e368cf208eb23596e67c794d700eaf690ec659dce7a00;

    function _getSettlementGatewayStorage() internal pure returns (SettlementGatewayStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _SETTLEMENT_GATEWAY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    constructor(address registry_, address appchainGateway_, address appchainNativeToken_) {
        require(_isNotZero(registry = registry_), ZeroRegistryAddress());
        require(_isNotZero(appchainGateway = appchainGateway_), ZeroAppchainGatewayAddress());
        require(_isNotZero(appchainNativeToken = appchainNativeToken_), ZeroAppchainNativeTokenAddress());

        appchainAlias = AddressAliasHelper.applyL1ToL2Alias(address(this));
    }

    /* ============ Initialization ============ */

    function initialize(address admin_) external initializer {
        require(_isNotZero(_getSettlementGatewayStorage().admin = admin_), ZeroAdminAddress());
    }

    /* ============ Interactive Functions ============ */

    function depositSenderFunds(address inbox_, uint256 amount_) external {
        require(ERC20Helper.transferFrom(appchainNativeToken, msg.sender, address(this), amount_), TransferFailed());
        require(ERC20Helper.approve(appchainNativeToken, inbox_, type(uint256).max), ApproveFailed());

        IERC20InboxLike(inbox_).depositERC20(amount_);
    }

    function sendParameters(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external {
        _sendParameters(inboxes_, gasLimit_, gasPrice_, _getEncodedParameters(keyChains_));
    }

    function sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external {
        _sendParametersAsRetryableTickets(
            inboxes_,
            gasLimit_,
            gasPrice_,
            maxSubmissionCost_,
            nativeTokensToSend_,
            _getEncodedParameters(keyChains_)
        );
    }

    /* ============ View/Pure Functions ============ */

    function admin() external view returns (address admin_) {
        return _getSettlementGatewayStorage().admin;
    }

    /* ============ Internal Interactive Functions ============ */

    function _sendParameters(
        address[] calldata inboxes_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        bytes memory data_
    ) internal {
        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            IERC20InboxLike(inboxes_[index_]).sendContractTransaction({
                gasLimit_: gasLimit_,
                maxFeePerGas_: gasPrice_,
                to_: appchainGateway,
                value_: 0,
                data_: data_
            });
        }
    }

    function _sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_,
        bytes memory data_
    ) internal {
        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            IERC20InboxLike(inboxes_[index_]).createRetryableTicket({
                to_: appchainGateway,
                l2CallValue_: 0,
                maxSubmissionCost_: maxSubmissionCost_,
                excessFeeRefundAddress_: appchainAlias,
                callValueRefundAddress_: appchainAlias,
                gasLimit_: gasLimit_,
                maxFeePerGas_: gasPrice_,
                tokenTotalFeeAmount_: nativeTokensToSend_,
                data_: data_
            });
        }
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getEncodedParameters(bytes[][] calldata keyChains_) internal view returns (bytes memory encoded_) {
        require(keyChains_.length > 0, EmptyKeys());
        return _encodeParameters(keyChains_, IParameterRegistry(registry).get(keyChains_));
    }

    function _encodeParameters(
        bytes[][] calldata keyChains_,
        bytes32[] memory values_
    ) internal pure returns (bytes memory encoded_) {
        return abi.encodeCall(IAppchainGatewayLike.receiveParameters, (keyChains_, values_));
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        isNotZero_ = input_ != address(0);
    }

    function _revertIfNotAdmin() internal view {
        require(msg.sender == _getSettlementGatewayStorage().admin, NotAdmin());
    }

    /* ============ Upgradeability ============ */

    /**
     * @dev   Authorizes the upgrade of the contract.
     * @param newImplementation_ The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation_) internal view override onlyAdmin {
        // TODO: Consider reverting if there is no code at the new implementation address.
        require(newImplementation_ != address(0), ZeroImplementationAddress());
    }
}
