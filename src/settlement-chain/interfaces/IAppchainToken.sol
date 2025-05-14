// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "../../../lib/oz/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "../../../lib/oz/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20Errors } from "../../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

/**
 * @title  Interface for the Appchain Token.
 * @notice This interface exposes functionality for wrapping and unwrapping tokens for use as appchain native gas.
 */
interface IAppchainToken is IERC20, IERC20Metadata, IERC20Errors, IMigratable {
    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the underlying token address is being set to zero (i.e. address(0)).
    error ZeroUnderlying();

    /// @notice Thrown when the amount to deposit or withdraw is zero.
    error ZeroAmount();

    /// @notice Thrown when the recipient address is zero (i.e. address(0)).
    error ZeroRecipient();

    /**
     * @notice Thrown when the `ERC20.transfer` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFailed`.
     */
    error TransferFailed();

    /**
     * @notice Thrown when the `ERC20.transferFrom` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFromFailed`.
     */
    error TransferFromFailed();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets `value_` as the allowance of `spender_` over `owner_`'s tokens, given `owner_'s signed approval.
     * @param  owner_    The owner of the tokens.
     * @param  spender_  The spender of the tokens.
     * @param  value_    The value of the tokens.
     * @param  deadline_ The deadline of the permit (must be a timestamp in the future).
     * @param  v_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Deposits `amount_` of the underlying token.
     * @param  amount_ The amount of the underlying token to deposit.
     */
    function deposit(uint256 amount_) external;

    /**
     * @notice Deposits `amount_` of the underlying token, given `owner_`'s signed approval.
     * @notice The permit signature must be for the underlying token, not for this token.
     * @param  amount_   The amount of the underlying token to deposit.
     * @param  deadline_ The deadline of the permit (must be a timestamp in the future).
     * @param  v_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositWithPermit(uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external;

    /**
     * @notice Deposits `amount_` of the underlying token for `recipient_`.
     * @param  recipient_ The recipient of the underlying token.
     * @param  amount_    The amount of the underlying token to deposit.
     * @dev    This function conforms to `ERC20Wrapper.depositFor`.
     */
    function depositFor(address recipient_, uint256 amount_) external returns (bool success_);

    /**
     * @notice Deposits `amount_` of the underlying token for `recipient_`, given `owner_`'s signed approval.
     * @notice The permit signature must be for the underlying token, not for this token.
     * @param  recipient_ The recipient of the underlying token.
     * @param  amount_    The amount of the underlying token to deposit.
     * @param  deadline_  The deadline of the permit (must be a timestamp in the future).
     * @param  v_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @dev    This function conforms to `ERC20Wrapper.depositFor`.
     */
    function depositForWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (bool success_);

    /**
     * @notice Withdraws `amount_` of the underlying token.
     * @param  amount_ The amount of the underlying token to withdraw.
     */
    function withdraw(uint256 amount_) external;

    /**
     * @notice Withdraws `amount_` of the underlying token for `recipient_`.
     * @param  recipient_ The recipient of the underlying token.
     * @param  amount_    The amount of the underlying token to withdraw.
     * @dev    This function conforms to `ERC20Wrapper.withdrawTo`.
     */
    function withdrawTo(address recipient_, uint256 amount_) external returns (bool success_);

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the EIP712 domain separator used in the encoding of a signed digest.
    // slither-disable-next-line naming-convention
    function DOMAIN_SEPARATOR() external view returns (bytes32 domainSeparator_);

    /// @notice Returns the EIP712 typehash used in the encoding of a signed digest for a permit.
    // slither-disable-next-line naming-convention
    function PERMIT_TYPEHASH() external pure returns (bytes32 permitTypehash_);

    /// @notice Returns the address of the underlying token.
    function underlying() external view returns (address underlying_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /**
     * @dev    Returns the EIP-712 digest for a permit.
     * @param  owner_    The owner of the tokens.
     * @param  spender_  The spender of the tokens.
     * @param  value_    The value of the tokens.
     * @param  nonce_    The nonce of the permit signature.
     * @param  deadline_ The deadline of the permit signature.
     * @return digest_   The EIP-712 digest.
     */
    function getPermitDigest(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_
    ) external view returns (bytes32 digest_);

    /**
     * @notice Returns the current nonce for `owner_` that must be included for the next valid permit signature.
     * @param  owner_ The owner of the tokens.
     * @return nonce_ The nonce of the owner.
     */
    function nonces(address owner_) external view returns (uint256 nonce_);
}
