// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IVersioned
 * @notice Contracts self-report version string from pure function
 */
interface IVersioned {
    /**
     * @notice Returns semver version string
     */
    function version() external pure returns (string memory);
}
