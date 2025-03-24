// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC1967 {
    /**
     * @dev   Emitted when the implementation is upgraded.
     * @param implementation The address of the new implementation.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the address of the current implementation.
     */
    function implementation() external view returns (address implementation_);
}
