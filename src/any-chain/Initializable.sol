// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IInitializable } from "./interfaces/IInitializable.sol";

/**
 * @title Implementation for first-time initializing of a proxy to an implementation with initialization arguments.
 */
contract Initializable is IInitializable {
    /**
     * @dev Storage slot with the address of the current implementation.
     *      `keccak256('eip1967.proxy.implementation') - 1`.
     */
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IInitializable
    function initialize(address implementation_, bytes calldata initializeCallData_) external {
        if (implementation_ == address(0)) revert ZeroImplementation();

        // slither-disable-next-line assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }

        // NOTE: If the `initializeCallData_` is empty, the proxy will not be called (i.e. no call to some `initialize`
        // function), which may be the desired behavior, but if it is not, it does expose the proxy to be initialized
        // by anyone, with any arguments, once this transaction is completed.
        if (initializeCallData_.length == 0) return;

        // slither-disable-next-line controlled-delegatecall
        (bool success_, bytes memory returnData_) = implementation_.delegatecall(initializeCallData_);

        if (!success_) revert InitializationFailed(returnData_);

        // If the call was successful and the return data is empty, the target is not a contract.
        if (returnData_.length == 0 && implementation_.code.length == 0) revert EmptyCode(implementation_);
    }
}
