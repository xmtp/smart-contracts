// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Interface for first-time initializing of a proxy to an implementation with initialization arguments.
 */
interface IInitializable {
    /// @notice Thrown when the implementation address is zero (i.e. address(0)).
    error ZeroImplementation();

    /// @notice Thrown when the initialization fails.
    error InitializationFailed(bytes errorData);

    /// @notice Thrown when the implementation code is empty.
    error EmptyCode(address implementation);

    /**
     * @notice Initializes the contract with respect to the implementation.
     * @param  implementation_     The address of the implementation.
     * @param  initializeCallData_ The data to initialize the proxy with, with respect to the implementation.
     */
    function initialize(address implementation_, bytes calldata initializeCallData_) external;
}
