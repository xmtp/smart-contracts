// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IInitializable {
    error ZeroImplementation();

    error InitializationFailed(bytes errorData);

    error EmptyCode(address implementation);

    function initialize(address implementation_, bytes calldata initializeCallData_) external;
}
