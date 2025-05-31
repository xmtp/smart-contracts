// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library AddressAliasHelper {
    uint160 internal constant _OFFSET = uint160(0x1111000000000000000000000000000000001111);

    /**
     * @notice Convert an L1 address into its L2 alias, which will be the msg.sender on the L2.
     * @param  account_ The address on L1 that will trigger a tx to L2.
     * @return alias_   The address on L2 that will be the msg.sender.
     * @dev    This applies for L2->L3 as well.
     */
    function applyL1ToL2Alias(address account_) internal pure returns (address alias_) {
        unchecked {
            return address(uint160(account_) + _OFFSET);
        }
    }

    /**
     * @notice Convert an L2 alias address into its L1 address, which will be the address that triggered the tx to L2.
     * @param  alias_   The address on L2 that will be the msg.sender.
     * @return account_ The address on L1 that triggered the tx to L2.
     * @dev    This applies for L2->L3 as well.
     */
    function undoL1ToL2Alias(address alias_) internal pure returns (address account_) {
        unchecked {
            return address(uint160(alias_) - _OFFSET);
        }
    }
}
