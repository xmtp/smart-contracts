// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1967 } from "./interfaces/IERC1967.sol";
import { IMigratable } from "./interfaces/IMigratable.sol";

/**
 * @title Abstract implementation for exposing the ability to migrate a contract, extending ERC-1967.
 */
abstract contract Migratable is IMigratable {
    /* ============ Constants/Immutables ============ */

    /**
     * @dev Storage slot with the address of the current implementation.
     *      `keccak256('eip1967.proxy.implementation') - 1`.
     */
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IERC1967
    function implementation() public view returns (address implementation_) {
        // slither-disable-next-line assembly
        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Performs an arbitrary migration by delegate-calling `migrator_`.
     * @param migrator_ The address of a trusted migrator contract the will have the authority to perform any state
     *                  changes, ETH transfers, and contract calls on behalf of this contract.
     * @dev   The migrator fallback code defines the entire migration process, and takes no user-defined arguments.
     */
    // slither-disable-next-line controlled-delegatecall
    function _migrate(address migrator_) internal {
        if (migrator_ == address(0)) revert ZeroMigrator();

        // NOTE: No `IERC1967.Upgraded` event is emitted here, since migration may not entail a change in the
        //       implementation, and even then, that new implementation will only be known after the migration.
        emit Migrated(migrator_);

        // NOTE: The migrator is expected to be a trusted contract approved by administration, and has the authority to
        //       perform any state changes, ETH transfers, and contract calls on behalf of this contract.
        (bool success_, bytes memory returnData_) = migrator_.delegatecall("");

        if (!success_) revert MigrationFailed(migrator_, returnData_);

        // If the call was successful and the return data is empty, the target is not a contract.
        if (returnData_.length == 0 && migrator_.code.length == 0) revert EmptyCode(migrator_);
    }
}
