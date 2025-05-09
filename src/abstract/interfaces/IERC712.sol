// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Typed structured data hashing and signing via EIP-712.
 * @dev   The interface as defined by EIP-712: https://eips.ethereum.org/EIPS/eip-712
 */
interface IERC712 {
    /* ============ View/Pure Functions ============ */

    /// @notice Returns the EIP712 domain separator used in the encoding of a signed digest.
    // slither-disable-next-line naming-convention
    function DOMAIN_SEPARATOR() external view returns (bytes32 domainSeparator_);
}
