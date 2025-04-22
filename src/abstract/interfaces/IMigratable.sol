// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1967 } from "./IERC1967.sol";

/**
 * @title  Minimal interface defining an implementation that allows its proxy to be migrated to a new implementation
 * @notice Unlike a simple upgrade, a migration is defined as:
 *          - Logic to determine the migration flow based on any conditions, and/or
 *          - Logic to determine the implementation to upgrade to, and/or
 *          - Logic to determine if the upgrade or migration should occur, and/or
 *          - State changes to the proxy storage, and/or
 *          - Setting the proxy's implementation slot.
 *         All the above can be kicked off by anyone, and without parameters, which is useful in governance models.
 */
interface IMigratable is IERC1967 {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the implementation is migrated.
     * @param  migrator The address of the migrator, which the proxy has delegatecalled to perform the migration.
     * @dev    The migrator contains fixed arbitrary code to manipulate storage, including the implementation slot.
     */
    event Migrated(address indexed migrator);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the migrator being delegatecalled is zero (i.e. address(0)).
    error ZeroMigrator();

    /**
     * @notice Thrown when the migration fails (i.e. the delegatecall to the migrator reverts).
     * @param  migrator_   The address of the migrator, which the proxy has delegatecalled to perform the migration.
     * @param  revertData_ The revert data from the migration.
     */
    error MigrationFailed(address migrator_, bytes revertData_);

    /**
     * @notice Thrown when the migrator is empty (i.e. has no code).
     * @param  migrator_ The address of the migrator, which the proxy has delegatecalled to perform the migration.
     */
    error EmptyCode(address migrator_);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Initiates a migration of the proxy, in a way defined by the implementation.
     * @dev    Normally, the implementation has a way of determining the migrator that needs to be delegatecalled.
     */
    function migrate() external;
}
