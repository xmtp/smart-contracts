// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFirstTimeInitializable } from "./interfaces/IFirstTimeInitializable.sol";

// TODO: Consider inheriting from OZ's `Initializable` so it can check and guarantee the initialization status of the
//       proxy contract itself.

/**
 * @title Implementation for first-time atomic initializing of a proxy to an implementation with initialization
 *        arguments.
 * @dev   This contract is expected to be the first and default implementation of a Proxy, so that any Proxy can have a
 *        constant constructor (and thus proxied implementation), despite remaining completely transparency, which is
 *        very helpful to allow consistency in address determinism regardless the final intended proxied implementation
 *        address. Thus, no Proxy should be left in a state of proxying this contract.
 */
contract FirstTimeInitializable is IFirstTimeInitializable {
    /**
     * @dev Storage slot with the address of the current implementation.
     *      `keccak256('eip1967.proxy.implementation') - 1`.
     */
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IFirstTimeInitializable
    function initialize(address implementation_, bytes calldata initializeCallData_) external {
        if (implementation_ == address(0)) revert ZeroImplementation();

        // slither-disable-next-line assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }

        // NOTE: If the `initializeCallData_` is empty, the proxy will not be called (i.e. no call to some `initialize`
        // function), which may be the desired behavior, but if it is not, it does expose the proxy to be initialized
        // by anyone, with any arguments, once this transaction is completed, assuming the proxied implementation even
        // has an initializer. However, since there is no way to ensure the `initializeCallData_` actually calls some
        // `initialize` function, there is really no point enforcing non-empty `initializeCallData_` here.
        if (initializeCallData_.length == 0) return;

        // slither-disable-next-line controlled-delegatecall
        (bool success_, bytes memory returnData_) = implementation_.delegatecall(initializeCallData_);

        if (!success_) revert InitializationFailed(returnData_);

        // If the call was successful and the return data is empty, the target is not a contract.
        if (returnData_.length == 0 && implementation_.code.length == 0) revert EmptyCode(implementation_);
    }
}
