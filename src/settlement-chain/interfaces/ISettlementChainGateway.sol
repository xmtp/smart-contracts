// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for a Settlement Chain Gateway.
 * @notice A SettlementChainGateway exposes the ability to send parameters to any app chain gateways, via their
 *         respective inboxes on the settlement chain.
 */
interface ISettlementChainGateway is IMigratable, IRegistryParametersErrors {
    /* ============ Events ============ */

    /**
     * @notice Emitted when fee tokens have been sent to the app chain (becoming native gas token).
     * @param  chainId       The chain ID of the target app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  amount        The amount of tokens sent.
     */
    event Deposit(uint256 indexed chainId, uint256 indexed messageNumber, uint256 amount);

    /**
     * @notice Emitted when parameters have been sent to the app chain.
     * @param  chainId       The chain ID of the target app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  nonce         The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys          The keys of the parameters.
     */
    event ParametersSent(uint256 indexed chainId, uint256 indexed messageNumber, uint256 nonce, string[] keys);

    /**
     * @notice Emitted when the inbox for a chain ID has been updated.
     * @param  chainId The chain ID.
     * @param  inbox   The inbox address.
     */
    event InboxUpdated(uint256 indexed chainId, address indexed inbox);

    /**
     * @notice Emitted when fee tokens have been withdrawn from the settlement chain gateway.
     * @param  amount    The amount of tokens withdrawn.
     * @param  recipient The recipient of the tokens.
     */
    event Withdrawal(uint256 amount, address indexed recipient);

    /**
     * @notice Emitted when the pause status is set.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the app chain gateway address is zero (i.e. address(0)).
    error ZeroAppChainGateway();

    /// @notice Thrown when the fee token address is zero (i.e. address(0)).
    error ZeroFeeToken();

    /**
     * @notice Thrown when the `ERC20.transferFrom` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFromFailed`.
     */
    error TransferFromFailed();

    /// @notice Thrown when no chain IDs are provided.
    error NoChainIds();

    /// @notice Thrown when no keys are provided.
    error NoKeys();

    /// @notice Thrown when the chain ID is not supported.
    error UnsupportedChainId(uint256 chainId);

    /// @notice Thrown when any pausable function is called when the contract is paused.
    error Paused();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when the balance is zero.
    error ZeroBalance();

    /// @notice Thrown when the amount is zero.
    error ZeroAmount();

    /// @notice Thrown when the recipient is zero (i.e. address(0)).
    error ZeroRecipient();

    /* ============ Initialization ============ */

    /// @notice Initializes the contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits fee tokens as gas token to an app chain.
     * @param  chainId_   The chain ID of the target app chain.
     * @param  recipient_ The recipient of the tokens.
     * @param  amount_    The amount of tokens to deposit.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     */
    function deposit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external;

    /**
     * @notice Deposits fee tokens as gas token to an app chain, given caller's signed approval.
     * @param  chainId_   The chain ID of the target app chain.
     * @param  recipient_ The recipient of the tokens.
     * @param  amount_    The amount of tokens to deposit.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     * @param  deadline_  The deadline of the permit (must be the current or future timestamp).
     * @param  v_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositWithPermit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Deposits fee tokens as gas token to an app chain, by wrapping underlying fee tokens.
     * @param  chainId_   The chain ID of the target app chain.
     * @param  recipient_ The recipient of the tokens.
     * @param  amount_    The amount of underlying fee tokens to deposit.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     */
    function depositFromUnderlying(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external;

    /**
     * @notice Deposits fee tokens as gas token to an app chain, by wrapping underlying fee tokens, given caller's
     *         signed approval.
     * @param  chainId_   The chain ID of the target app chain.
     * @param  recipient_ The recipient of the tokens.
     * @param  amount_    The amount of underlying fee tokens to deposit.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     * @param  deadline_  The deadline of the permit (must be the current or future timestamp).
     * @param  v_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositFromUnderlyingWithPermit(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call).
     * @param  chainIds_     The chain IDs of the target app chains.
     * @param  keys_         The keys of the parameters.
     * @param  gasLimit_     The gas limit for the transaction on the app chain.
     * @param  gasPrice_     The gas price for the transaction on the app chain.
     * @param  amountToSend_ The amount of fee tokens to send with the call to fund the alias on each app chain.
     * @return totalSent_    The total amount of fee tokens sent to all app chains combined.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     * @dev    `amountToSend_` must be greater than or equal to the sum of `gasLimit_` multiplied by `gasPrice_`.
     * @dev    The total amount of fee tokens that will be pulled from the caller is `chainIds_.length` multiplied by
     *         `amountToSend_` (which is returned as `totalSent_`).
     */
    function sendParameters(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) external returns (uint256 totalSent_);

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call), given
     *         caller's signed approval to pull fee tokens.
     * @param  chainIds_     The chain IDs of the target app chains.
     * @param  keys_         The keys of the parameters.
     * @param  gasLimit_     The gas limit for the transaction on the app chain.
     * @param  gasPrice_     The gas price for the transaction on the app chain.
     * @param  amountToSend_ The amount of fee tokens to send with the call to fund the alias on each app chain.
     * @param  deadline_     The deadline of the permit (must be the current or future timestamp).
     * @param  v_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @return totalSent_    The total amount of fee tokens sent to all app chains combined.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     * @dev    `amountToSend_` must be greater than or equal to the sum of `gasLimit_` multiplied by `gasPrice_`.
     * @dev    The total amount of fee tokens that will be pulled from the caller is `chainIds_.length` multiplied by
     *         `amountToSend_` (which is returned as `totalSent_`).
     */
    function sendParametersWithPermit(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 totalSent_);

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call).
     * @param  chainIds_     The chain IDs of the target app chains.
     * @param  keys_         The keys of the parameters.
     * @param  gasLimit_     The gas limit for the transaction on the app chain.
     * @param  gasPrice_     The gas price for the transaction on the app chain.
     * @param  amountToSend_ The amount of fee tokens to send with the call to fund the alias on each app chain, which
     *                       will first be converted from underlying fee tokens.
     * @return totalSent_    The total amount of fee tokens sent to all app chains combined.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     * @dev    `amountToSend_` must be greater than or equal to the sum of `gasLimit_` multiplied by `gasPrice_`.
     * @dev    The total amount of fee tokens that will be pulled from the caller is `chainIds_.length` multiplied by
     *         `amountToSend_` (which is returned as `totalSent_`).
     */
    function sendParametersFromUnderlying(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) external returns (uint256 totalSent_);

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call), given
     *         caller's signed approval to pull underlying fee tokens.
     * @param  chainIds_     The chain IDs of the target app chains.
     * @param  keys_         The keys of the parameters.
     * @param  gasLimit_     The gas limit for the transaction on the app chain.
     * @param  gasPrice_     The gas price for the transaction on the app chain.
     * @param  amountToSend_ The amount of fee tokens to send with the call to fund the alias on each app chain, which
     *                       will first be converted from underlying fee tokens.
     * @param  deadline_     The deadline of the permit (must be the current or future timestamp).
     * @param  v_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_            An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @return totalSent_    The total amount of fee tokens sent to all app chains combined.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     * @dev    `amountToSend_` must be greater than or equal to the sum of `gasLimit_` multiplied by `gasPrice_`.
     * @dev    The total amount of fee tokens that will be pulled from the caller is `chainIds_.length` multiplied by
     *         `amountToSend_` (which is returned as `totalSent_`).
     */
    function sendParametersFromUnderlyingWithPermit(
        uint256[] calldata chainIds_,
        string[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 totalSent_);

    /**
     * @notice Updates the inbox for a chain ID.
     * @param  chainId_ The chain ID.
     */
    function updateInbox(uint256 chainId_) external;

    /**
     * @notice Receives withdrawal of fee tokens from the app chain gateway.
     * @param  recipient_ The recipient of the tokens.
     * @return amount_    The amount of fee tokens withdrawn.
     */
    function receiveWithdrawal(address recipient_) external returns (uint256 amount_);

    /**
     * @notice Receives withdrawal of fee tokens from the app chain gateway, and unwraps them into underlying fee tokens.
     * @param  recipient_ The recipient of the underlying fee tokens.
     * @return amount_    The amount of fee tokens withdrawn.
     */
    function receiveWithdrawalIntoUnderlying(address recipient_) external returns (uint256 amount_);

    /**
     * @notice Updates the pause status.
     * @dev    Ensures the new pause status is not equal to the old pause status.
     */
    function updatePauseStatus() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the inbox.
    function inboxParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the app chain gateway.
    function appChainGateway() external view returns (address appChainGateway_);

    /// @notice This contract's alias address on the L3 app chain.
    function appChainAlias() external view returns (address appChainAlias_);

    /// @notice The address of the fee token on the settlement chain, that is used to pay for gas on app chains.
    function feeToken() external view returns (address feeToken_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);

    /// @notice The inbox address for a chain ID.
    function getInbox(uint256 chainId_) external view returns (address inbox_);
}
