// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1967 } from "./IERC1967.sol";

interface IMigratable is IERC1967 {
    /* ============ Events ============ */

    event Migrated(address indexed migrator);

    /* ============ Custom Errors ============ */

    error ZeroMigrator();

    error MigrationFailed(bytes returnData_);

    error EmptyCode(address target_);

    /* ============ Interactive Functions ============ */

    function migrate() external;
}
