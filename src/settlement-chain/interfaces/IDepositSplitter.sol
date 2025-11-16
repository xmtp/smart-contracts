// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IVersioned } from "../../abstract/interfaces/IVersioned.sol";

/**
 * @title  Interface for the Deposit Splitter.
 * @notice This interface exposes functionality for splitting deposits between the Payer Registry and App Chain.
 */
interface IDepositSplitter is IVersioned {
    /* ============ Custom Errors ============ */

    /**
     * @notice Thrown when the `ERC20.transferFrom` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFromFailed`.
     */
    error TransferFromFailed();

    /// @notice Thrown when the fee token is the zero address.
    error ZeroFeeToken();

    /// @notice Thrown when the payer registry is the zero address.
    error ZeroPayerRegistry();

    /// @notice Thrown when the settlement chain gateway is the zero address.
    error ZeroSettlementChainGateway();

    /// @notice Thrown when the app chain ID is zero.
    error ZeroAppChainId();

    /// @notice Thrown when the total amount is zero.
    error ZeroTotalAmount();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits `payerRegistryAmount_` fee tokens into the Payer Registry for `payer_`, and `appChainAmount_`
     *         fee tokens into the App Chain for `appChainRecipient_`.
     * @param  payer_                The address of the payer.
     * @param  payerRegistryAmount_  The amount of fee tokens to deposit into the Payer Registry.
     * @param  appChainRecipient_    The address of the recipient on the AppChain.
     * @param  appChainAmount_       The amount of fee tokens to deposit into the AppChain.
     * @param  appChainGasLimit_     The gas limit for the AppChain deposit.
     * @param  appChainMaxFeePerGas_ The maximum fee per gas (EIP-1559) for the AppChain deposit.
     */
    function deposit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainMaxFeePerGas_
    ) external;

    /**
     * @notice Deposits `payerRegistryAmount_` fee tokens into the Payer Registry for `payer_`, and `appChainAmount_`
     *         fee tokens into the App Chain for `appChainRecipient_`.
     * @param  payer_                The address of the payer.
     * @param  payerRegistryAmount_  The amount of fee tokens to deposit into the Payer Registry.
     * @param  appChainRecipient_    The address of the recipient on the AppChain.
     * @param  appChainAmount_       The amount of fee tokens to deposit into the AppChain.
     * @param  appChainGasLimit_     The gas limit for the AppChain deposit.
     * @param  appChainMaxFeePerGas_ The maximum fee per gas (EIP-1559) for the AppChain deposit.
     * @param  deadline_             The deadline of the permit (must be the current or future timestamp).
     * @param  v_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositWithPermit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainMaxFeePerGas_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Deposits `payerRegistryAmount_` fee tokens into the Payer Registry for `payer_`, and `appChainAmount_`
     *         fee tokens into the App Chain for `appChainRecipient_`, wrapping them from underlying fee tokens.
     * @param  payer_                The address of the payer.
     * @param  payerRegistryAmount_  The amount of fee tokens to deposit into the Payer Registry.
     * @param  appChainRecipient_    The address of the recipient on the AppChain.
     * @param  appChainAmount_       The amount of fee tokens to deposit into the AppChain.
     * @param  appChainGasLimit_     The gas limit for the AppChain deposit.
     * @param  appChainMaxFeePerGas_ The maximum fee per gas (EIP-1559) for the AppChain deposit.
     */
    function depositFromUnderlying(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainMaxFeePerGas_
    ) external;

    /**
     * @notice Deposits `payerRegistryAmount_` fee tokens into the Payer Registry for `payer_`, and `appChainAmount_`
     *         fee tokens into the App Chain for `appChainRecipient_`, wrapping them from underlying fee tokens.
     * @param  payer_                The address of the payer.
     * @param  payerRegistryAmount_  The amount of fee tokens to deposit into the Payer Registry.
     * @param  appChainRecipient_    The address of the recipient on the AppChain.
     * @param  appChainAmount_       The amount of fee tokens to deposit into the AppChain.
     * @param  appChainGasLimit_     The gas limit for the AppChain deposit.
     * @param  appChainMaxFeePerGas_ The maximum fee per gas (EIP-1559) for the AppChain deposit.
     * @param  deadline_             The deadline of the permit (must be the current or future timestamp).
     * @param  v_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_                    An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositFromUnderlyingWithPermit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainMaxFeePerGas_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The app chain ID.
    function appChainId() external view returns (uint256 appChainId_);

    /// @notice The address of the fee token contract used for deposits.
    function feeToken() external view returns (address feeToken_);

    /// @notice The address of the payer registry.
    function payerRegistry() external view returns (address payerRegistry_);

    /// @notice The address of the settlement chain gateway.
    function settlementChainGateway() external view returns (address settlementChainGateway_);
}
