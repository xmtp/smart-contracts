// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC712 } from "./interfaces/IERC712.sol";

/**
 * @title An abstract implementation of EIP-712 for typed structured data hashing and signing.
 */
abstract contract ERC712 is IERC712 {
    /* ============ Variables ============ */

    /// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 internal constant _EIP712_DOMAIN_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev Initial Chain ID set at deployment.
    uint256 internal immutable _initialChainId;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.ERC712
     * @notice The UUPS storage for the ERC712 contract.
     * @param  initialDomainSeparator Initial EIP-712 domain separator set at initialization.
     */
    struct ERC712Storage {
        bytes32 initialDomainSeparator;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.ERC712")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _ERC712_STORAGE_LOCATION =
        0xc7effa11ad597798220888e5d1ba4eeddcc8c2635d01dae8b9f958ac905c1100;

    function _getERC712Storage() internal pure returns (ERC712Storage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _ERC712_STORAGE_LOCATION
        }
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the EIP-712 domain separator.
     */
    constructor() {
        _initialChainId = block.chainid;
    }

    /* ============ Initialization ============ */

    function _initializeERC712() internal {
        _getERC712Storage().initialDomainSeparator = _getDomainSeparator();
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IERC712
    // slither-disable-next-line naming-convention
    function DOMAIN_SEPARATOR() public view returns (bytes32 domainSeparator_) {
        return block.chainid == _initialChainId ? _getERC712Storage().initialDomainSeparator : _getDomainSeparator();
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Computes the EIP-712 domain separator.
     * @return domainSeparator_ The EIP-712 domain separator.
     */
    function _getDomainSeparator() internal view returns (bytes32 domainSeparator_) {
        return
            keccak256(
                abi.encode(
                    _EIP712_DOMAIN_HASH,
                    keccak256(bytes(_name())),
                    keccak256(bytes(_version())),
                    block.chainid,
                    address(this)
                )
            );
    }

    /**
     * @dev    Returns the digest to be signed, via EIP-712, given an internal digest (i.e. hash struct).
     * @param  internalDigest_ The internal digest.
     * @return digest_         The digest to be signed.
     */
    function _getDigest(bytes32 internalDigest_) internal view returns (bytes32 digest_) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), internalDigest_));
    }

    /// @dev The name of the contract.
    function _name() internal view virtual returns (string memory name_);

    /// @dev The version of the contract.
    function _version() internal view virtual returns (string memory version_);
}
