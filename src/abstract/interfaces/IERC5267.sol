// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC712 } from "./IERC712.sol";

/**
 * @title EIP-5267 extended from EIP-712.
 * @dev   The interface as defined by EIP-5267: https://eips.ethereum.org/EIPS/eip-5267
 */
interface IERC5267 is IERC712 {
    /* ============ Events ============ */

    /// @notice MAY be emitted to signal that the domain could have changed.
    event EIP712DomainChanged();

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns the fields and values that describe the domain separator used by this contract for EIP-712.
     * @return fields_            A bit map where bit i is set to 1 if and only if domain field i is present
     *                            (0 ≤ i ≤ 4). Bits are read from least significant to most significant, and fields are
     *                            indexed in the order that is specified by EIP-712, identical to the order in which
     *                            they are listed (i.e. name, version, chainId, verifyingContract, and salt).
     * @return name_              The user readable name of signing domain.
     * @return version_           The current major version of the signing domain.
     * @return chainId_           The EIP-155 chain id.
     * @return verifyingContract_ The address of the contract that will verify the signature.
     * @return salt_              A disambiguating salt for the protocol.
     * @return extensions_        A list of EIP numbers, each of which MUST refer to an EIP that extends EIP-712 with
     *                              new domain fields, along with a method to obtain the value for those fields, and
     *                              potentially conditions for inclusion. The value of fields does not affect their
     *                              inclusion.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields_,
            string memory name_,
            string memory version_,
            uint256 chainId_,
            address verifyingContract_,
            bytes32 salt_,
            uint256[] memory extensions_
        );
}
