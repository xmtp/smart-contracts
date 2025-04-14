// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IProxy {
    /// @dev Thrown when a zero address is provided as an implementation.
    error ZeroImplementation();
}
