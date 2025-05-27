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
     * @param  inbox         The inbox address, from which you can derive the app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  amount        The amount of tokens sent.
     */
    event Deposit(uint256 indexed chainId, address indexed inbox, uint256 indexed messageNumber, uint256 amount);

    /**
     * @notice Emitted when parameters have been sent to the app chain.
     * @param  chainId       The chain ID of the target app chain.
     * @param  inbox         The inbox address, from which you can derive the app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  nonce         The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys          The keys of the parameters.
     */
    event ParametersSent(
        uint256 indexed chainId,
        address indexed inbox,
        uint256 indexed messageNumber,
        uint256 nonce,
        bytes[] keys
    );

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

    /* ============ Initialization ============ */

    /// @notice Initializes the contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits fee tokens as gas token to an app chain.
     * @param  chainId_ The chain ID of the target app chain.
     * @param  amount_  The amount of tokens to deposit.
     */
    function deposit(uint256 chainId_, uint256 amount_) external;

    /**
     * @notice Deposits fee tokens as gas token to an app chain, by wrapping underlying fee tokens.
     * @param  chainId_ The chain ID of the target app chain.
     * @param  amount_  The amount of underlying tokens to deposit.
     */
    function depositFromUnderlying(uint256 chainId_, uint256 amount_) external;

    /**
     * @notice Sends parameters to the app chain as a direct contract call.
     * @param  chainIds_  The chain IDs of the target app chains.
     * @param  keys_      The keys of the parameters.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice, or
     *         the message will be stuck indefinitely. While this is cheaper, `sendParametersAsRetryableTickets` is more
     *         reliable and robust.
     */
    function sendParameters(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external;

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call).
     * @param  chainIds_           The chain IDs of the target app chains.
     * @param  keys_               The keys of the parameters.
     * @param  gasLimit_           The gas limit for the transaction on the app chain.
     * @param  gasPrice_           The gas price for the transaction on the app chain.
     * @param  maxSubmissionCost_  The maximum submission cost for the transaction.
     * @param  feeTokensToSend_    The amount of fee tokens to send with the call to fund the alias on the app chain.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     */
    function sendParametersAsRetryableTickets(
        uint256[] calldata chainIds_,
        bytes[] calldata keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 feeTokensToSend_
    ) external;

    /**
     * @notice Updates the inbox for a chain ID.
     * @param  chainId_ The chain ID.
     */
    function updateInbox(uint256 chainId_) external;

    /**
     * @notice Withdraws fee tokens from the settlement chain gateway.
     * @param  recipient_ The recipient of the tokens.
     * @return amount_    The amount of fee tokens withdrawn.
     */
    function withdraw(address recipient_) external returns (uint256 amount_);

    /**
     * @notice Withdraws fee tokens from the settlement chain gateway, and unwraps them into underlying tokens.
     * @param  recipient_ The recipient of the underlying tokens.
     * @return amount_    The amount of fee tokens withdrawn.
     */
    function withdrawIntoUnderlying(address recipient_) external returns (uint256 amount_);

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the inbox.
    function inboxParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the app chain gateway.
    function appChainGateway() external view returns (address appChainGateway_);

    /// @notice This contract's alias address on the L3 app chain.
    function appChainAlias() external view returns (address appChainAlias_);

    /// @notice The address of the fee token on the settlement chain, that is used to pay for gas on app chains.
    function feeToken() external view returns (address feeToken_);

    /// @notice The inbox address for a chain ID.
    function getInbox(uint256 chainId_) external view returns (address inbox_);
}
