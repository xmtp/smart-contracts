// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
    ERC20PermitUpgradeable
} from "../../lib/oz-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike, IPermitErc20Like } from "./interfaces/External.sol";
import { IAppchainToken } from "./interfaces/IAppchainToken.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Appchain Token.
 * @notice This contract exposes functionality for wrapping and unwrapping tokens for use as appchain native gas.
 */
contract AppchainToken is IAppchainToken, Migratable, ERC20PermitUpgradeable {
    /* ============ Constants/Immutables ============ */

    /**
     * @inheritdoc IAppchainToken
     * @dev        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
     */
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @inheritdoc IAppchainToken
    address public immutable parameterRegistry;

    /// @inheritdoc IAppchainToken
    address public immutable underlying;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.AppchainToken
     * @notice The UUPS storage for the appchain token.
     */
    struct AppchainTokenStorage {
        uint256 __placeholder;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.AppchainToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _APPCHAIN_TOKEN_STORAGE_LOCATION =
        0xf3113fb37d01584b69fb0553afaccecd5878bffdf9a02c0b156b2e4dcbafe000;

    // slither-disable-start dead-code
    function _getAppchainTokenStorage() internal pure returns (AppchainTokenStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _APPCHAIN_TOKEN_STORAGE_LOCATION
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
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistry());
        require(_isNotZero(underlying = underlying_), ZeroUnderlying());
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IAppchainToken
    function initialize() public initializer {
        __ERC20Permit_init("XMTP Appchain Token");
        __ERC20_init("XMTP Appchain Token", "aXMTP");
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IAppchainToken
    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) public override(IAppchainToken, ERC20PermitUpgradeable) {
        super.permit(owner_, spender_, value_, deadline_, v_, r_, s_);
    }

    /// @inheritdoc IAppchainToken
    function wrap(uint256 amount_) external {
        _wrap(msg.sender, amount_);
    }

    /// @inheritdoc IAppchainToken
    function wrapWithPermit(uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external {
        _wrapWithPermit(msg.sender, amount_, deadline_, v_, r_, s_);
    }

    /// @inheritdoc IAppchainToken
    function depositFor(address recipient_, uint256 amount_) external returns (bool success_) {
        _wrap(recipient_, amount_);
        return true;
    }

    /// @inheritdoc IAppchainToken
    function depositForWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (bool success_) {
        _wrapWithPermit(recipient_, amount_, deadline_, v_, r_, s_);
        return true;
    }

    /// @inheritdoc IAppchainToken
    function unwrap(uint256 amount_) external {
        _unwrap(msg.sender, amount_);
    }

    /// @inheritdoc IAppchainToken
    function withdrawTo(address recipient_, uint256 amount_) external returns (bool success_) {
        _unwrap(recipient_, amount_);
        return true;
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    // slither-disable-start naming-convention
    /// @inheritdoc IAppchainToken
    function DOMAIN_SEPARATOR()
        external
        view
        override(IAppchainToken, ERC20PermitUpgradeable)
        returns (bytes32 domainSeparator_)
    {
        return _domainSeparatorV4();
    }
    // slither-disable-end naming-convention

    /// @inheritdoc IAppchainToken
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.appchainToken.migrator";
    }

    /// @inheritdoc IAppchainToken
    function nonces(
        address owner_
    ) public view override(IAppchainToken, ERC20PermitUpgradeable) returns (uint256 nonce_) {
        return super.nonces(owner_);
    }

    /// @inheritdoc IAppchainToken
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

    function _wrapWithPermit(
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

        _wrap(recipient_, amount_);
    }

    function _wrap(address recipient_, uint256 amount_) internal {
        if (amount_ == 0) revert ZeroAmount();
        if (recipient_ == address(0)) revert ZeroRecipient();

        SafeTransferLib.safeTransferFrom(underlying, msg.sender, address(this), amount_);

        _mint(recipient_, amount_);
    }

    function _unwrap(address recipient_, uint256 amount_) internal {
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

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }
}
