// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1967 } from "../abstract/interfaces/IERC1967.sol";

/**
 * @title Minimal Migrator for migrating a proxy from a specific implementation to a new implementation.
 */
contract Migrator {
    /// @notice Thrown when the from implementation is the zero address.
    error ZeroFromImplementation();

    /// @notice Thrown when the to implementation is the zero address.
    error ZeroToImplementation();

    /// @notice Thrown when the implementation is not the expected implementation.
    error UnexpectedImplementation();

    /**
     * @dev Storage slot with the address of the current implementation.
     *      `keccak256('eip1967.proxy.implementation') - 1`.
     */
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The implementation to migrate proxies from.
    address public immutable fromImplementation;

    /// @dev The implementation to migrate proxies to.
    address public immutable toImplementation;

    /**
     * @dev   Constructs the contract such that it proxies calls to the given implementation.
     * @param fromImplementation_ The address of the implementation to migrate a proxy from.
     * @param toImplementation_   The address of the implementation to migrate a proxy to.
     */
    constructor(address fromImplementation_, address toImplementation_) {
        if ((fromImplementation = fromImplementation_) == address(0)) revert ZeroFromImplementation();
        if ((toImplementation = toImplementation_) == address(0)) revert ZeroToImplementation();
    }

    /// @dev Migrates a proxy to the new implementation.
    fallback() external {
        address implementation_;

        // slither-disable-next-line assembly
        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }

        if (implementation_ != fromImplementation) revert UnexpectedImplementation();

        implementation_ = toImplementation;

        // slither-disable-next-line assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }

        emit IERC1967.Upgraded(implementation_);
    }
}
