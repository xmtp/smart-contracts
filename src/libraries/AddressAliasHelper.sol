// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  Library for converting settlement layer addresses to roll-up layer alias addresses, and vice versa.
 * @notice Roll-up layer address aliasing as per EIP-6735 (see https://eips.ethereum.org/EIPS/eip-6735).
 */
library AddressAliasHelper {
    uint160 internal constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    /**
     * @notice Convert a settlement layer address to roll-up layer alias address.
     * @param  account_ The address on the settlement layer that will trigger a tx to the roll-up layer.
     * @return alias_   The address on the roll-up layer that will be the msg.sender.
     */
    function toAlias(address account_) internal pure returns (address alias_) {
        unchecked {
            return address(uint160(account_) + OFFSET);
        }
    }

    /**
     * @notice Convert a roll-up layer alias address to settlement layer address.
     * @param  alias_   The address on the roll-up layer that will be the msg.sender.
     * @return account_ The address on the settlement layer that triggered the tx to the roll-up layer.
     */
    function fromAlias(address alias_) internal pure returns (address account_) {
        unchecked {
            return address(uint160(alias_) - OFFSET);
        }
    }
}
