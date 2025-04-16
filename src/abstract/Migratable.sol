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
     * @param migrator_ The address of a migrator contract.
     * @dev   The migrator fallback code defines the entire migration process, and takes no user-defined arguments.
     */
    function _migrate(address migrator_) internal {
        require(migrator_ != address(0), ZeroMigrator());

        // NOTE: Can merge into `Upgraded` event since it must conform to the EIP-1967 standard.
        emit Migrated(migrator_);

        // slither-disable-next-line low-level-calls
        (bool success_, bytes memory returnData_) = migrator_.delegatecall(hex"");

        require(success_, MigrationFailed(returnData_));

        // If the call was successful and the return data is empty, the target is not a contract.
        if (returnData_.length == 0 && migrator_.code.length == 0) revert EmptyCode(migrator_);

        // slither-disable-next-line reentrancy-events
        emit Upgraded(implementation());
    }
}
