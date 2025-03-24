// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "../../lib/oz-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { IParameterRegistry } from "./interfaces/External.sol";

import { IAppchainGateway } from "./interfaces/IAppchainGateway.sol";

// TODO: Message ordering.
// TODO: Admin set/reset and event.

contract AppchainGateway is IAppchainGateway, Initializable, UUPSUpgradeable {
    /* ============ Constants ============ */

    address public immutable registry;
    address public immutable settlementGateway;
    address public immutable settlementGatewayAlias;

    /* ============ Storage ============ */

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.AppchainGateway
    struct AppchainGatewayStorage {
        address admin;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.AppchainGateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _APPCHAIN_GATEWAY_STORAGE_LOCATION =
        0x8e43b35ddefc63e0bdc181c39cd6feb4af10c24845f3467a81ac0eb6f4af3e00;

    function _getAppchainGatewayStorage() internal pure returns (AppchainGatewayStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _APPCHAIN_GATEWAY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    modifier onlySettlementGateway() {
        _revertIfNotSettlementGateway();
        _;
    }

    /* ============ Constructor ============ */

    constructor(address registry_, address settlementGateway_) {
        require(_isNotZero(registry = registry_), ZeroRegistryAddress());
        require(_isNotZero(settlementGateway = settlementGateway_), ZeroSettlementGatewayAddress());

        settlementGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(settlementGateway_);
    }

    /* ============ Initialization ============ */

    function initialize(address admin_) external initializer {
        require(_isNotZero(_getAppchainGatewayStorage().admin = admin_), ZeroAdminAddress());
    }

    /* ============ Interactive Functions ============ */

    function receiveParameters(
        bytes[][] calldata keyChains_,
        bytes32[] calldata values_
    ) external onlySettlementGateway {
        IParameterRegistry(registry).set(keyChains_, values_);
    }

    /* ============ View/Pure Functions ============ */

    function admin() external view returns (address admin_) {
        return _getAppchainGatewayStorage().admin;
    }

    /* ============ Internal Interactive Functions ============ */

    /* ============ Internal View/Pure Functions ============ */

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        isNotZero_ = input_ != address(0);
    }

    function _revertIfNotAdmin() internal view {
        require(msg.sender == _getAppchainGatewayStorage().admin, NotAdmin());
    }

    function _revertIfNotSettlementGateway() internal view {
        require(msg.sender == settlementGatewayAlias, NotSettlementGateway());
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
