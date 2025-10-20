// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1967} from "../../src/abstract/interfaces/IERC1967.sol";

/**
 * @title GenericEIP1967Migrator
 * @notice Minimal migrator that upgrades an EIP-1967 proxy to a new implementation.
 *
 * @dev HOW IT WORKS
 * - This contract is deployed as a *standalone* “migrator”.
 * - Your proxied contract implements the XMTP `Migratable` pattern. When governance
 *   sets this migrator’s address in the ParameterRegistry and calls `proxy.migrate()`,
 *   the proxy will `delegatecall("")` into this contract (empty calldata).
 * - Because it’s a `delegatecall`, *this fallback executes in the proxy’s storage
 *   context*, so it can write the EIP-1967 implementation slot on the proxy.
 *
 * WHAT IT DOES
 * - Writes `NEW_IMPL` into the EIP-1967 implementation slot.
 * - Emits the standard `IERC1967.Upgraded(newImpl)` event.
 *
 * WHAT IT DOES NOT DO
 * - Does not run any initialization or data migration on the new implementation.
 *   If you need state transforms or an `initialize(...)` call, use a purpose-built
 *   migrator that (after setting the slot) `delegatecall`s the new impl with the
 *   desired calldata.
 *
 * SAFETY NOTES
 * - This migrator is intentionally tiny: fewer moving parts, easier to audit.
 * - Make sure `NEW_IMPL` preserves storage layout and initializer semantics.
 * - Only allow `migrate()` to be reachable via your governed parameter (`migrator` key).
 */
contract GenericEIP1967Migrator {
    error InvalidImplementation();

    /// @notice The implementation that the proxy will be upgraded to.
    address public immutable NEW_IMPL;

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant _IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @param newImpl_ The address of the new implementation (must be non-zero).
     */
    constructor(address newImpl_) {
        if (newImpl_ == address(0)) revert InvalidImplementation();
        NEW_IMPL = newImpl_;
    }

    /**
     * @notice Entry point when the proxy `delegatecall`s this contract with empty calldata.
     * @dev Runs in the *proxy’s* context (storage is the proxy’s), so we can sstore the slot.
     *      Emits the standard ERC-1967 `Upgraded` event via the imported interface.
     */
    fallback() external payable {
        address impl = NEW_IMPL;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, impl)
        }

        emit IERC1967.Upgraded(impl);
    }
}
