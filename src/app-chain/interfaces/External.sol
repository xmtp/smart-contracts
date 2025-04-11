// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  IParameterRegistryLike
 * @notice Subset interface for a ParameterRegistry.
 */
interface IParameterRegistryLike {
    function set(bytes[] calldata keyChain_, bytes32 value_) external;

    function get(bytes calldata key_) external view returns (bytes32 value_);
}
