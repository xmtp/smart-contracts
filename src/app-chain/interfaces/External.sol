// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IParameterRegistryLike {
    function set(bytes[] calldata keyChain_, bytes32 value_) external;

    function get(bytes calldata key_) external view returns (bytes32 value_);
}
