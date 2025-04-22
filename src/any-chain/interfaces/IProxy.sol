// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IProxy {
    /// @notice Thrown when the implementation address is zero (i.e. address(0)).
    error ZeroImplementation();
}
