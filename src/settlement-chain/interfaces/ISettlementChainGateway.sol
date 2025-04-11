// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

/**
 * @title  ISettlementChainGateway
 * @notice Interface for the SettlementChainGateway.
 */
interface ISettlementChainGateway is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when tokens have been sent to the app chain (becoming native gas token).
     * @param  inbox         The inbox address, from which you can derive the app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  amount        The amount of tokens sent.
     */
    event SenderFundsDeposited(address indexed inbox, uint256 indexed messageNumber, uint256 amount);

    /**
     * @notice Emitted when parameters have been sent to the app chain.
     * @param  inbox         The inbox address, from which you can derive the app chain.
     * @param  messageNumber The message number, unique per inbox.
     * @param  nonce         The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keyChains     The key chains of the parameters.
     */
    event ParametersSent(
        address indexed inbox,
        uint256 indexed messageNumber,
        uint256 indexed nonce,
        bytes[][] keyChains
    );

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the registry address is zero.
    error ZeroRegistryAddress();

    /// @notice Thrown when the app chain gateway address is zero.
    error ZeroAppChainGatewayAddress();

    /// @notice Thrown when the app chain native token address is zero.
    error ZeroAppChainNativeTokenAddress();

    /// @notice Thrown when the `ERC20.approve` call fails.
    error ApproveFailed();

    /// @notice Thrown when the `ERC20.transfer` call fails.
    error TransferFailed();

    /// @notice Thrown when no inboxes are provided.
    error NoInboxes();

    /// @notice Thrown when no key chains are provided.
    error NoKeyChains();

    /* ============ Initialization ============ */

    /// @notice Initializes the contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits tokens as gas token to the app chain.
     * @param  inbox_  The inbox address, which targets an app chain.
     * @param  amount_ The amount of tokens to deposit.
     */
    function depositSenderFunds(address inbox_, uint256 amount_) external;

    /**
     * @notice Sends parameters to the app chain as a direct contract call.
     * @param  inboxes_   The inboxes to send parameters to, which target app chains respectively.
     * @param  keyChains_ The key chains of the parameters.
     * @param  gasLimit_  The gas limit for the transaction on the app chain.
     * @param  gasPrice_  The gas price for the transaction on the app chain.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice, or
     *         the message will be stuck indefinitely. While this is cheaper, `sendParametersAsRetryableTickets` is more
     *         reliable and robust.
     */
    function sendParameters(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external;

    /**
     * @notice Sends parameters to the app chain as retryable tickets (which may be a direct contract call).
     * @param  inboxes_            The inboxes to send parameters to, which target app chains respectively.
     * @param  keyChains_          The key chains of the parameters.
     * @param  gasLimit_           The gas limit for the transaction on the app chain.
     * @param  gasPrice_           The gas price for the transaction on the app chain.
     * @param  maxSubmissionCost_  The maximum submission cost for the transaction.
     * @param  nativeTokensToSend_ The amount of tokens to send with the call to fund the alias on the app chain.
     * @dev    This will perform an L2->L3 message, where the settlement gateway alias must have enough balance to pay
     *         for the function call (IAppChainGateway.receiveParameters), and the gas limit and price must suffice. If
     *         not, the message will remain as a retryable ticket on the app chain, that anyone can trigger and pay for.
     */
    function sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The key of the migrator parameter.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the registry.
    function registry() external view returns (address registry_);

    /// @notice The address of the app chain gateway.
    function appChainGateway() external view returns (address appChainGateway_);

    /// @notice The alias this contracts address on the app chain.
    function appChainAlias() external view returns (address appChainAlias_);

    /// @notice The address of token on the settlement app chain that is used as native gas token on the app chain.
    function appChainNativeToken() external view returns (address appChainNativeToken_);
}
