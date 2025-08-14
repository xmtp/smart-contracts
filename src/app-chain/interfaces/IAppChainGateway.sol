// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for an App Chain Gateway.
 * @notice The AppChainGateway exposes the ability to receive parameters from the settlement chain gateway.
 */
interface IAppChainGateway is IMigratable, IRegistryParametersErrors {
    /* ============ Events ============ */

    /**
     * @notice Emitted when parameters are received from the settlement chain.
     * @param  nonce The nonce of the parameter transmission (to prevent out-of-sequence parameter updates).
     * @param  keys  The keys of the parameters.
     * @dev    The `values` are not emitted, as they are not relevant to indexing this contract, and will be emitted
     *         by the app chain parameter registry.
     */
    event ParametersReceived(uint256 indexed nonce, string[] keys);

    /**
     * @notice Emitted when funds are deposited from the settlement chain.
     * @param  recipient The address to which the funds will be delivered to.
     * @param  amount    The amount of funds received.
     */
    event DepositReceived(address indexed recipient, uint256 amount);

    /**
     * @notice Emitted when the pause status is set.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /**
     * @notice Emitted when funds are withdrawn from the app chain.
     * @param  account   The address of the account that withdrew the funds.
     * @param  messageId The message ID of the withdrawal.
     * @param  recipient The address to which the funds will be delivered to on the settlement chain.
     * @param  amount    The amount of funds withdrawn.
     */
    event Withdrawal(address indexed account, uint256 indexed messageId, address indexed recipient, uint256 amount);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the settlement chain gateway address is zero (i.e. address(0)).
    error ZeroSettlementChainGateway();

    /// @notice Thrown when the caller is not the settlement chain gateway (i.e. its L3 alias address).
    error NotSettlementChainGateway();

    /// @notice Thrown when the recipient address is zero (i.e. address(0)).
    error ZeroRecipient();

    /// @notice Thrown when the withdrawal amount is zero.
    error ZeroWithdrawalAmount();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when any pausable function is called when the contract is paused.
    error Paused();

    /// @notice Thrown when the transfer fails.
    error TransferFailed();

    /* ============ Initialization ============ */

    /// @notice Initializes the parameter registry, as used by a proxy contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Withdraws funds from the app chain to the settlement chain.
     * @param  recipient_ The address to which the funds will be delivered to on the settlement chain.
     */
    function withdraw(address recipient_) external payable;

    /**
     * @notice Withdraws funds from the app chain to the settlement chain, unwrapped as underlying fee token.
     * @param  recipient_ The address to which the funds will be delivered to on the settlement chain.
     */
    function withdrawIntoUnderlying(address recipient_) external payable;

    /**
     * @notice Receives funds from the settlement chain.
     * @param  recipient_ The address to which the funds will be delivered to.
     * @dev    The recipient will receive the forwarded amount attached as payable.
     */
    function receiveDeposit(address recipient_) external payable;

    /**
     * @notice Receives parameters from the settlement chain.
     * @param  nonce_  The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys_   The keys of the parameters.
     * @param  values_ The values of each parameter.
     * @dev    The caller must be the settlement chain gateway's L3 alias address.
     */
    function receiveParameters(uint256 nonce_, string[] calldata keys_, bytes32[] calldata values_) external;

    /**
     * @notice Updates the pause status.
     * @dev    Ensures the new pause status is not equal to the old pause status.
     */
    function updatePauseStatus() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the settlement chain gateway.
    function settlementChainGateway() external view returns (address settlementChainGateway_);

    /**
     * @notice The L3 alias address of the settlement chain gateway (i.e. the expected caller of the `receiveParameters`
     *         function).
     */
    function settlementChainGatewayAlias() external view returns (address settlementChainGatewayAlias_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (string memory key_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);
}
