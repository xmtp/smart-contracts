// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "./IMigratable.sol";

/**
 * @title  IParameterRegistry
 * @notice Common interface for parameter registries.
 */
interface IParameterRegistry is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a parameter is set.
     * @param  key   The key of the parameter.
     * @param  value The value of the parameter.
     */
    event ParameterSet(bytes indexed key, bytes32 indexed value);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the caller is not an admin.
    error NotAdmin();

    /// @notice Thrown when no keys are provided.
    error NoKeys();

    /// @notice Thrown when the array length mismatch.
    error ArrayLengthMismatch();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the parameter registry.
     * @param  admins_ The addresses of the admins.
     */
    function initialize(address[] calldata admins_) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets several parameters.
     * @param  keys_   The keys of each parameter to set.
     * @param  values_ The values of the parameters.
     */
    function set(bytes[] calldata keys_, bytes32[] calldata values_) external;

    /**
     * @notice Sets a parameter.
     * @param  key_   The key of the parameter to set.
     * @param  value_ The value of the parameter.
     */
    function set(bytes calldata key_, bytes32 value_) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns whether an account is an admin.
     * @param  account_ The address of the account to check.
     * @return isAdmin_ True if the account is an admin, false otherwise.
     */
    function isAdmin(address account_) external view returns (bool isAdmin_);

    /**
     * @notice Gets the values of several parameters.
     * @param  keys_   The keys of each parameter to get.
     * @return values_ The values of the parameters.
     */
    function get(bytes[] calldata keys_) external view returns (bytes32[] memory values_);

    /**
     * @notice Gets the value of a parameter.
     * @param  key_   The full key of the parameter to get.
     * @return value_ The value of the parameter.
     */
    function get(bytes calldata key_) external view returns (bytes32 value_);

    /// @notice The parameter registry key of the migrator parameter.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key of the admin parameter.
    function adminParameterKey() external pure returns (bytes memory key_);
}
