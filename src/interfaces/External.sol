// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IERC20Like
 * @notice Minimal interface for ERC20 token balance checks
 */
interface IERC20Like {
    function balanceOf(address account) external view returns (uint256 balance);
}

/**
 * @title IParameterRegistryLike
 * @notice Minimal interface for ParameterRegistry
 */
interface IParameterRegistryLike {
    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_);
}
