// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC5267 } from "./interfaces/IERC5267.sol";

import { ERC712 } from "./ERC712.sol";

/**
 * @title An abstract implementation of EIP-5267 for domain retrieval and typed structured data hashing and signing.
 */
abstract contract ERC5267 is IERC5267, ERC712 {
    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     */
    constructor() ERC712() {}

    /* ============ Initialization ============ */

    function _initializeERC5267() internal {
        _initializeERC712();
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IERC5267
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
        )
    {
        return (
            hex"0f", // 01111 (salt is not used in the domain separator)
            _name(),
            _version(),
            block.chainid,
            address(this),
            0,
            new uint256[](0)
        );
    }
}
