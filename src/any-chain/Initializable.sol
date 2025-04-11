// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IInitializable } from "./interfaces/IInitializable.sol";

/**
 * @title Implementation for first-time initializing of a proxy to an implementation with initialization arguments.
 */
contract Initializable is IInitializable {
    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.implementation') - 1`.
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IInitializable
    function initialize(address implementation_, bytes calldata initializeCallData_) external {
        if (implementation_ == address(0)) revert ZeroImplementation();

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }

        if (initializeCallData_.length == 0) return;

        (bool success_, bytes memory returnData_) = implementation_.delegatecall(initializeCallData_);

        require(success_, InitializationFailed(returnData_));

        // If the call was successful and the return data is empty, the target is not a contract.
        if (returnData_.length == 0 && implementation_.code.length == 0) revert EmptyCode(implementation_);
    }
}
