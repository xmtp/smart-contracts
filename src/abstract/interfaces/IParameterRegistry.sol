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
     * @param  key      The full key of the parameter.
     * @param  keyChain The components (key chain) of the parameter, for parsing.
     * @param  value    The value of the parameter.
     */
    event ParameterSet(bytes indexed key, bytes[] keyChain, bytes32 indexed value);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the caller is not an admin.
    error NotAdmin();

    /// @notice Thrown when no key chains are provided.
    error NoKeyChains();

    /// @notice Thrown when the array length mismatch.
    error ArrayLengthMismatch();

    /// @notice Thrown when the key chain is empty.
    error EmptyKeyChain();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the parameter registry.
     * @param  admins_ The addresses of the admins.
     */
    function initialize(address[] calldata admins_) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets several parameters.
     * @param  keyChains_ The components (key chain) of each parameter to set.
     * @param  values_    The values of the parameters.
     */
    function set(bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    /**
     * @notice Sets a parameter.
     * @param  keyChain_ The components (key chain) of the parameter to set.
     * @param  value_    The value of the parameter.
     */
    function set(bytes[] calldata keyChain_, bytes32 value_) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns whether an account is an admin.
     * @param  account_ The address of the account to check.
     * @return isAdmin_ True if the account is an admin, false otherwise.
     */
    function isAdmin(address account_) external view returns (bool isAdmin_);

    /**
     * @notice Gets the values of several parameters.
     * @param  keyChains_ The components (key chain) of each parameter to get.
     * @return values_    The values of the parameters.
     */
    function get(bytes[][] calldata keyChains_) external view returns (bytes32[] memory values_);

    /**
     * @notice Gets the value of a parameter.
     * @param  keyChain_ The components (key chain) of the parameter to get.
     * @return value_    The value of the parameter.
     */
    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_);

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
