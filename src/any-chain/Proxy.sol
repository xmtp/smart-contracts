// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IProxy } from "./interfaces/IProxy.sol";

/**
 * @title Minimal transparent proxy with initial implementation.
 */
contract Proxy is IProxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     *      `keccak256('eip1967.proxy.implementation') - 1`.
     */
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev   Constructs the contract given the address of some implementation.
     * @param implementation_ The address of some implementation.
     */
    constructor(address implementation_) {
        require(implementation_ != address(0), ZeroImplementation());

        // slither-disable-next-line assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }

    // slither-disable-next-line locked-ether
    fallback() external payable virtual {
        // slither-disable-next-line assembly
        assembly {
            let implementation_ := sload(_IMPLEMENTATION_SLOT)

            calldatacopy(0, 0, calldatasize())

            let result_ := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result_
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
