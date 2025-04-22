// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Strings } from "../../lib/oz/contracts/utils/Strings.sol";

library ParameterKeys {
    /* ============ Constants ============ */

    bytes internal constant DELIMITER = ".";

    /* ============ Custom Errors ============ */

    /// @notice Thrown when no key components are provided.
    error NoKeyComponents();

    /* ============ View/Pure Functions ============ */

    function getKey(bytes[] memory keyComponents_) internal pure returns (bytes memory key_) {
        require(keyComponents_.length > 0, NoKeyComponents());

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
