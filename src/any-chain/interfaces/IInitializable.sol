// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Initializable
 * @notice Interface for first-time initializing of a proxy to an implementation with initialization arguments.
 */
interface IInitializable {
    /// @notice Thrown when the implementation address is zero.
    error ZeroImplementation();

    /// @notice Thrown when the initialization fails.
    error InitializationFailed(bytes errorData);

    /// @notice Thrown when the implementation code is empty.
    error EmptyCode(address implementation);

    /**
     * @notice Initializes the contract.
     * @param  implementation_     The address of the implementation.
     * @param  initializeCallData_ The data to initialize the implementation with.
     */
    function initialize(address implementation_, bytes calldata initializeCallData_) external;
}
