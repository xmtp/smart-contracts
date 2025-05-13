// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Interface defining errors for Parameter Keys library.
 * @dev   This interface should be inherited by any contract that uses the Parameter Keys library in order to expose the
 *        errors that may be thrown by the library.
 */
interface IParameterKeysErrors {
    /// @notice Thrown when no key components are provided.
    error NoKeyComponents();
}
