// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1967 } from "./IERC1967.sol";

/**
 * @title  IMigratable
 * @notice Minimal interface defining an implementation that allows its proxy to be migrated.
 */
interface IMigratable is IERC1967 {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the implementation is migrated.
     * @param  migrator The address of the migrator.
     */
    event Migrated(address indexed migrator);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the migrator is zero.
    error ZeroMigrator();

    /**
     * @notice Thrown when the migration fails.
     * @param  returnData_ The return data from the migration.
     */
    error MigrationFailed(bytes returnData_);

    /**
     * @notice Thrown when the migrator is empty.
     * @param  migrator_ The address of the migrator.
     */
    error EmptyCode(address migrator_);

    /* ============ Interactive Functions ============ */

    /// @notice Migrates the proxy to a new implementation, in a way defined by the implementation.
    function migrate() external;
}
