// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import {
    ERC20PermitUpgradeable
} from "../../lib/oz-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { ERC20Upgradeable } from "../../lib/oz-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { IERC20Metadata } from "../../lib/oz/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IFeeToken } from "./interfaces/IFeeToken.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IPermitErc20Like } from "./interfaces/External.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Fee Token.
 * @notice This contract exposes functionality for wrapping and unwrapping tokens for use as fees in the protocol.
 */
contract FeeToken is IFeeToken, Migratable, ERC20PermitUpgradeable {
    /* ============ Constants/Immutables ============ */

    /**
     * @inheritdoc IFeeToken
     * @dev        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
     */
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @inheritdoc IFeeToken
    address public immutable parameterRegistry;

    /// @inheritdoc IFeeToken
    address public immutable underlying;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.FeeToken
     * @notice The UUPS storage for the fee token.
     */
    struct FeeTokenStorage {
        uint256 __placeholder;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.FeeToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _FEE_TOKEN_STORAGE_LOCATION =
        0x5671b09487cb30093710a244e87d44c3076fe3dd19f604be8dafc153e2d9cb00;

    // slither-disable-start dead-code
    function _getFeeTokenStorage() internal pure returns (FeeTokenStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _FEE_TOKEN_STORAGE_LOCATION
        }
    }
    // slither-disable-end dead-code

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @param  underlying_        The address of the underlying token.
     * @dev    The parameter registry and underlying token must not be the zero address.
     * @dev    The parameter registry and underlying token are immutable so that they are inlined in the contract code,
     *         and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address underlying_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(underlying = underlying_)) revert ZeroUnderlying();

        parameterRegistry = parameterRegistry_;
        underlying = underlying_;

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IFeeToken
    function initialize() public initializer {
        __ERC20Permit_init("XMTP Fee Token");
        __ERC20_init("XMTP Fee Token", "fXMTP");
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IFeeToken
    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) public override(IFeeToken, ERC20PermitUpgradeable) {
        super.permit(owner_, spender_, value_, deadline_, v_, r_, s_);
    }

    /// @inheritdoc IFeeToken
    function deposit(uint256 amount_) external {
        _deposit(msg.sender, amount_);
    }

    /// @inheritdoc IFeeToken
    function depositWithPermit(uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external {
        _depositWithPermit(msg.sender, amount_, deadline_, v_, r_, s_);
    }

    /// @inheritdoc IFeeToken
    function depositFor(address recipient_, uint256 amount_) external returns (bool success_) {
        _deposit(recipient_, amount_);
        return true;
    }

    /// @inheritdoc IFeeToken
    function depositForWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (bool success_) {
        _depositWithPermit(recipient_, amount_, deadline_, v_, r_, s_);
        return true;
    }

    /// @inheritdoc IFeeToken
    function withdraw(uint256 amount_) external {
        _withdraw(msg.sender, amount_);
    }

    /// @inheritdoc IFeeToken
    function withdrawTo(address recipient_, uint256 amount_) external returns (bool success_) {
        _withdraw(recipient_, amount_);
        return true;
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    // slither-disable-start naming-convention
    /// @inheritdoc IFeeToken
    function DOMAIN_SEPARATOR()
        external
        view
        override(IFeeToken, ERC20PermitUpgradeable)
        returns (bytes32 domainSeparator_)
    {
        return _domainSeparatorV4();
    }
    // slither-disable-end naming-convention

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(IERC20Metadata, ERC20Upgradeable) returns (uint8 decimals_) {
        return 6;
    }

    /// @inheritdoc IFeeToken
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.feeToken.migrator";
    }

    /// @inheritdoc IFeeToken
    function nonces(address owner_) public view override(IFeeToken, ERC20PermitUpgradeable) returns (uint256 nonce_) {
        return super.nonces(owner_);
    }

    /// @inheritdoc IFeeToken
    function getPermitDigest(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_
    ) external view returns (bytes32 digest_) {
        return _getPermitDigest(owner_, spender_, value_, nonce_, deadline_);
    }

    /* ============ Internal Interactive Functions ============ */

    function _depositWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) internal {
        // Ignore return value, as the permit may have already been used, and the allowance already approved.
        // slither-disable-start unchecked-lowlevel
        // slither-disable-start low-level-calls
        address(underlying).call(
            abi.encodeWithSelector(
                IPermitErc20Like.permit.selector,
                msg.sender,
                address(this),
                amount_,
                deadline_,
                v_,
                r_,
                s_
            )
        );
        // slither-disable-end unchecked-lowlevel
        // slither-disable-end low-level-calls

        _deposit(recipient_, amount_);
    }

    function _deposit(address recipient_, uint256 amount_) internal {
        if (amount_ == 0) revert ZeroAmount();
        if (recipient_ == address(0)) revert ZeroRecipient();

        SafeTransferLib.safeTransferFrom(underlying, msg.sender, address(this), amount_);

        _mint(recipient_, amount_);
    }

    function _withdraw(address recipient_, uint256 amount_) internal {
        if (amount_ == 0) revert ZeroAmount();
        if (recipient_ == address(0)) revert ZeroRecipient();

        _burn(msg.sender, amount_);

        SafeTransferLib.safeTransfer(underlying, recipient_, amount_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Returns the EIP-712 digest for a permit.
     * @param  owner_    The owner of the tokens.
     * @param  spender_  The spender of the tokens.
     * @param  value_    The value of the tokens.
     * @param  nonce_    The nonce of the permit signature.
     * @param  deadline_ The deadline of the permit signature.
     * @return digest_   The EIP-712 digest.
     */
    function _getPermitDigest(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes32 digest_) {
        return _hashTypedDataV4(keccak256(abi.encode(PERMIT_TYPEHASH, owner_, spender_, value_, nonce_, deadline_)));
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }
}
