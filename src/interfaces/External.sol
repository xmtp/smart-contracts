// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IERC20Like
 * @notice Minimal interface for ERC20 token balance checks
 */
interface IERC20Like {
    function balanceOf(address account) external view returns (uint256 balance);
}
