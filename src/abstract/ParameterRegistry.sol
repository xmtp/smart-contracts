// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { ParameterKeys } from "../libraries/ParameterKeys.sol";

import { IMigratable } from "./interfaces/IMigratable.sol";
import { IParameterRegistry } from "./interfaces/IParameterRegistry.sol";

import { Migratable } from "./Migratable.sol";

/**
 * @title  Abstract implementation for a Parameter Registry.
 * @notice A parameter registry is a contract that stores key-value pairs of parameters used by a protocol. Keys should
 *         be globally unique and human-readable strings (as bytes), for easier parsing and indexing. Keys can be set by
 *         admins, and whether an account is an admin is itself a key-value pair in the registry, which means that
 *         admins can be added and removed by other admins, and the parameter registry can be orphaned.
 */
abstract contract ParameterRegistry is IParameterRegistry, Migratable, Initializable {
    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.ParameterRegistry
     * @notice The UUPS storage for the parameter registry.
     * @param  parameters A mapping of key-value pairs of parameters.
     */
    struct ParameterRegistryStorage {
        mapping(bytes key => bytes32 value) parameters;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.ParameterRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PARAMETER_REGISTRY_STORAGE_LOCATION =
        0xefab3f4eb315eafaa267b58974a509c07c739fbfe8e62b4eff49c4ced6985000;

    function _getParameterRegistryStorage() internal pure returns (ParameterRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PARAMETER_REGISTRY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     */
    constructor() {
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IParameterRegistry
    function initialize(address[] calldata admins_) external initializer {
        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        bytes memory adminParameterKey_ = adminParameterKey();

        // Each admin-specific key is set to true (i.e. 1).
        for (uint256 index_; index_ < admins_.length; ++index_) {
            _setParameter($, _getAdminKey(adminParameterKey_, admins_[index_]), bytes32(uint256(1)));
        }
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IParameterRegistry
    function set(bytes[] calldata keys_, bytes32[] calldata values_) external onlyAdmin {
        if (keys_.length == 0) revert NoKeys();
        if (keys_.length != values_.length) revert ArrayLengthMismatch();

        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        for (uint256 index_; index_ < keys_.length; ++index_) {
            _setParameter($, keys_[index_], values_[index_]);
        }
    }

    /// @inheritdoc IParameterRegistry
    function set(bytes calldata key_, bytes32 value_) external onlyAdmin {
        _setParameter(_getParameterRegistryStorage(), key_, value_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IParameterRegistry
    function migratorParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IParameterRegistry
    function adminParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IParameterRegistry
    function isAdmin(address account_) public view returns (bool isAdmin_) {
        return _getRegistryParameter(_getAdminKey(adminParameterKey(), account_)) != bytes32(uint256(0));
    }

    /// @inheritdoc IParameterRegistry
    function get(bytes[] calldata keys_) external view returns (bytes32[] memory values_) {
        if (keys_.length == 0) revert NoKeys();

        values_ = new bytes32[](keys_.length);
        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        for (uint256 index_; index_ < keys_.length; ++index_) {
            values_[index_] = $.parameters[keys_[index_]];
        }
    }

    /// @inheritdoc IParameterRegistry
    function get(bytes calldata key_) external view returns (bytes32 value_) {
        return _getParameterRegistryStorage().parameters[key_];
    }

    /* ============ Internal Interactive Functions ============ */

    function _setParameter(ParameterRegistryStorage storage $, bytes memory key_, bytes32 value_) internal {
        emit ParameterSet(key_, $.parameters[key_] = value_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Returns the admin-specific key used to query to parameter registry to determine if an account is an admin.
     *      The admin-specific key is the concatenation of the admin parameter key and the address of the admin.
     *      For example, if the admin parameter key is "pr.isAdmin", then the key for admin
     *      0x1234567890123456789012345678901234567890 is "pr.isAdmin.0x1234567890123456789012345678901234567890".
     */
    function _getAdminKey(bytes memory adminParameterKey_, address account_) internal pure returns (bytes memory key_) {
        return ParameterKeys.combineKeyComponents(adminParameterKey_, ParameterKeys.addressToKeyComponent(account_));
    }

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return _getParameterRegistryStorage().parameters[key_];
    }

    function _revertIfNotAdmin() internal view {
        if (!isAdmin(msg.sender)) revert NotAdmin();
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }
}
