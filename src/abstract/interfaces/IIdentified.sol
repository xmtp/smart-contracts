// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IIdentified
 * @notice Contracts self-report contract name and version strings from pure functions
 */
interface IIdentified {
    /**
     * @notice Returns semver version string
     * @return version_ The semver version string
     */
    function version() external pure returns (string memory version_);

    /**
     * @notice Returns contract name
     * @return contractName_ The contract name
     */
    function contractName() external pure returns (string memory contractName_);
}
