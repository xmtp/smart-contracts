// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IParameterRegistryLike {
    function set(bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_);
}
