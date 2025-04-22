// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  Subset interface for a ParameterRegistry.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IParameterRegistryLike {
    function get(bytes calldata key_) external view returns (bytes32 value_);
}
