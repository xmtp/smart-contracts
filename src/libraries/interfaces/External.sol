// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  Subset interface for a ParameterRegistry.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IParameterRegistryLike {
    function set(string calldata key_, bytes32 value_) external;

    function get(string calldata key_) external view returns (bytes32 value_);

    function get(string[] calldata keys_) external view returns (bytes32[] memory values_);
}
