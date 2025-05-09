// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Strings } from "../../lib/oz/contracts/utils/Strings.sol";

/**
 * @title  Library for building parameter keys from components and non-bytes types
 * @notice A parameter key is a string that uniquely identifies a parameter.
 */
library ParameterKeys {
    /* ============ Constants ============ */

    /// @dev The delimiter used to combine key components.
    bytes internal constant DELIMITER = ".";

    /* ============ Custom Errors ============ */

    /// @notice Thrown when no key components are provided.
    error NoKeyComponents();

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Combines an array of key components into a single key, using the delimiter.
     * @param  keyComponents_ The key components to combine.
     * @return key_           The combined key.
     */
    function getKey(bytes[] memory keyComponents_) internal pure returns (bytes memory key_) {
        if (keyComponents_.length == 0) revert NoKeyComponents();

        // TODO: Perhaps compute the final size of the key and allocate the memory in one go. Best in assembly.
        for (uint256 index_; index_ < keyComponents_.length; ++index_) {
            key_ = index_ == 0 ? keyComponents_[index_] : combineKeyComponents(key_, keyComponents_[index_]);
        }
    }

    function combineKeyComponents(bytes memory left_, bytes memory right_) internal pure returns (bytes memory key_) {
        return abi.encodePacked(left_, DELIMITER, right_);
    }

    function addressToKeyComponent(address account_) internal pure returns (bytes memory keyComponent_) {
        return bytes(Strings.toHexString(account_));
    }

    function uint256ToKeyComponent(uint256 value_) internal pure returns (bytes memory keyComponent_) {
        return bytes(Strings.toString(value_));
    }
}
