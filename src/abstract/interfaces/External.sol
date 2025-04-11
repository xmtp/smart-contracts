// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IParameterRegistryLike
 * @notice Minimal interface for ParameterRegistry
 */
interface IParameterRegistryLike {
    function get(bytes calldata key_) external view returns (bytes32 value_);
}
