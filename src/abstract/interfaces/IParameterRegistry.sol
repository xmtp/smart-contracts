// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "./IMigratable.sol";

/**
 * @title  Common interface for a Parameter Registry.
 * @notice A parameter registry allows admins to set parameters, including whether an account is an admin, and allows
 *         any account/contract to query the values of parameters.
 */
interface IParameterRegistry is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a parameter is set.
     * @param  key   The key of the parameter (which is generally a human-readable string, for clarity).
     * @param  value The value of the parameter (which can represent any value type).
     * @dev    Values that are not value types (e.g. bytes, arrays, structs, etc.) must be the hash of their contents.
     */
    event ParameterSet(bytes indexed key, bytes32 indexed value);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the caller is not an admin (e.g. when setting a parameter).
    error NotAdmin();

    /// @notice Thrown when no keys are provided (e.g. when setting or getting parameters).
    error NoKeys();

    /// @notice Thrown when the array length mismatch (e.g. when setting multiple parameters).
    error ArrayLengthMismatch();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the parameter registry, as used by a proxy contract.
     * @param  admins_ The addresses of the admins that can set parameters.
     * @dev    Whether an account is an admin is tracked as a key-value pair in the registry itself.
     */
    function initialize(address[] calldata admins_) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets several parameters.
     * @param  keys_   The keys of each parameter to set.
     * @param  values_ The values of each parameter.
     * @dev    The length of the `keys_` and `values_` arrays must be the same.
     * @dev    The caller must be an admin.
     */
    function set(bytes[] calldata keys_, bytes32[] calldata values_) external;

    /**
     * @notice Sets a parameter.
     * @param  key_   The key of the parameter to set.
     * @param  value_ The value of the parameter.
     * @dev    The caller must be an admin.
     */
    function set(bytes calldata key_, bytes32 value_) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns whether an account is an admin (i.e. an account that can set parameters).
     * @param  account_ The address of the account to check.
     * @return isAdmin_ True if the account is an admin, false otherwise.
     */
    function isAdmin(address account_) external view returns (bool isAdmin_);

    /**
     * @notice Gets the values of several parameters.
     * @param  keys_   The keys of each parameter to get.
     * @return values_ The values of each parameter.
     * @dev    The default value for each parameter is bytes32(0).
     */
    function get(bytes[] calldata keys_) external view returns (bytes32[] memory values_);

    /**
     * @notice Gets the value of a parameter.
     * @param  key_   The key of the parameter to get.
     * @return value_ The value of the parameter.
     * @dev    The default value for a parameter is bytes32(0).
     */
    function get(bytes calldata key_) external view returns (bytes32 value_);

    /**
     * @notice The parameter registry key used to fetch the migrator.
     * @return key_ The key of the migrator parameter.
     * @dev    Uniquely, the parameter registry uses itself, so the key-value pair is stored in the contract itself.
     */
    function migratorParameterKey() external pure returns (bytes memory key_);

    /**
     * @notice The parameter registry key used to fetch the status of an admin.
     * @return key_ The key of the admin parameter, which is a component of the full key, when prefixing an address.
     * @dev    Uniquely, the parameter registry uses itself, so the key-value pair is stored in the contract itself.
     */
    function adminParameterKey() external pure returns (bytes memory key_);
}
