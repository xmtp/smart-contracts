// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IIdentified } from "../../abstract/interfaces/IIdentified.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for the Payer Registry.
 * @notice This interface exposes functionality:
 *           - for payers to deposit, request withdrawals, and finalize withdrawals of a fee token,
 *           - for some settler contract to settle usage fees for payers,
 *           - for anyone to send excess fee tokens in the contract to the fee distributor.
 */
interface IPayerRegistry is IMigratable, IIdentified, IRegistryParametersErrors {
    /* ============ Structs ============ */

    /**
     * @notice Represents a payer in the registry.
     * @param  balance               The signed balance of the payer (negative if debt).
     * @param  pendingWithdrawal     The amount of a pending withdrawal, if any.
     * @param  withdrawableTimestamp The timestamp when the pending withdrawal can be finalized.
     * @param  withdrawalNonce       The nonce associated with the pending withdrawal. Used for offchain tracking.
     */
    struct Payer {
        int104 balance;
        uint96 pendingWithdrawal;
        uint32 withdrawableTimestamp;
        uint24 withdrawalNonce;
    }

    /**
     * @notice Represents a payer and their fee.
     * @param  payer The address a payer.
     * @param  fee   The fee to settle for the payer.
     */
    struct PayerFee {
        address payer;
        uint96 fee;
    }

    /**
     * @notice Represents a delegation from a payer to a delegate (e.g., gateway).
     * @param  isActive   Whether the delegation is currently active.
     * @param  expiry     The timestamp when the delegation expires (0 for no expiry).
     * @param  createdAt  The timestamp when the delegation was created.
     */
    struct Delegation {
        bool isActive;
        uint64 expiry;
        uint64 createdAt;
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when a payer authorizes a delegate to sign on their behalf.
     * @param  payer    The address of the payer granting delegation.
     * @param  delegate The address of the delegate being authorized.
     * @param  expiry   The timestamp when the delegation expires (0 for no expiry).
     */
    event DelegationAuthorized(address indexed payer, address indexed delegate, uint64 expiry);

    /**
     * @notice Emitted when a payer revokes a delegate's authorization.
     * @param  payer    The address of the payer revoking delegation.
     * @param  delegate The address of the delegate being revoked.
     */
    event DelegationRevoked(address indexed payer, address indexed delegate);

    /**
     * @notice Emitted when the settler is updated.
     * @param  settler The address of the new settler.
     */
    event SettlerUpdated(address indexed settler);

    /**
     * @notice Emitted when the fee distributor is updated.
     * @param  feeDistributor The address of the new fee distributor.
     */
    event FeeDistributorUpdated(address indexed feeDistributor);

    /**
     * @notice Emitted when the minimum deposit is updated.
     * @param  minimumDeposit The new minimum deposit amount.
     */
    event MinimumDepositUpdated(uint96 minimumDeposit);

    /**
     * @notice Emitted when the withdraw lock period is updated.
     * @param  withdrawLockPeriod The new withdraw lock period.
     */
    event WithdrawLockPeriodUpdated(uint32 withdrawLockPeriod);

    /**
     * @notice Emitted when a deposit of fee tokens occurs for a payer.
     * @param  payer  The address of the payer.
     * @param  amount The amount of fee tokens deposited.
     */
    event Deposit(address indexed payer, uint96 amount);

    /**
     * @notice Emitted when a withdrawal is requested by a payer.
     * @param  payer                 The address of the payer.
     * @param  amount                The amount of fee tokens requested for withdrawal.
     * @param  withdrawableTimestamp The timestamp when the withdrawal can be finalized.
     * @param  nonce                 The nonce associated with the requested withdrawal.
     */
    event WithdrawalRequested(address indexed payer, uint96 amount, uint32 withdrawableTimestamp, uint24 nonce);

    /**
     * @notice Emitted when a payer's pending withdrawal is cancelled.
     * @param  payer The address of the payer.
     * @param  nonce The nonce associated with the cancelled withdrawal.
     */
    event WithdrawalCancelled(address indexed payer, uint24 nonce);

    /**
     * @notice Emitted when a payer's pending withdrawal is finalized.
     * @param  payer The address of the payer.
     * @param  nonce The nonce associated with the finalized withdrawal.
     */
    event WithdrawalFinalized(address indexed payer, uint24 nonce);

    /**
     * @notice Emitted when a payer's usage is settled.
     * @param  payerReportId The ID of the payer report triggering the settlement.
     * @param  payer  The address of the payer.
     * @param  amount The amount of fee tokens settled (the fee deducted from their balance).
     */
    event UsageSettled(bytes32 indexed payerReportId, address indexed payer, uint96 amount);

    /**
     * @notice Emitted when excess fee tokens are transferred to the fee distributor.
     * @param  amount The amount of excess fee tokens transferred.
     */
    event ExcessTransferred(uint96 amount);

    /**
     * @notice Emitted when the pause status is set.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when caller is not the settler.
    error NotSettler();

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the fee token address is being set to zero (i.e. address(0)).
    error ZeroFeeToken();

    /// @notice Thrown when the settler address is being set to zero (i.e. address(0)).
    error ZeroSettler();

    /// @notice Thrown when the fee distributor address is zero (i.e. address(0)).
    error ZeroFeeDistributor();

    /// @notice Thrown when the minimum deposit is being set to 0.
    error ZeroMinimumDeposit();

    /**
     * @notice Thrown when the `ERC20.transferFrom` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFromFailed`.
     */
    error TransferFromFailed();

    /**
     * @notice Thrown when the deposit amount is less than the minimum deposit.
     * @param  amount         The amount of fee tokens being deposited.
     * @param  minimumDeposit The minimum deposit amount.
     */
    error InsufficientDeposit(uint96 amount, uint96 minimumDeposit);

    /// @notice Thrown when a payer has insufficient balance for a withdrawal request.
    error InsufficientBalance();

    /// @notice Thrown when a withdrawal request of zero is made.
    error ZeroWithdrawalAmount();

    /// @notice Thrown when a withdrawal is pending for a payer.
    error PendingWithdrawalExists();

    /// @notice Thrown when a withdrawal is not pending for a payer.
    error NoPendingWithdrawal();

    /**
     * @notice Thrown when trying to finalize a withdrawal before the withdraw lock period has passed.
     * @param  timestamp             The current timestamp.
     * @param  withdrawableTimestamp The timestamp when the withdrawal can be finalized.
     * @param  nonce                 The nonce associated with the pending withdrawal.
     */
    error WithdrawalNotReady(uint32 timestamp, uint32 withdrawableTimestamp, uint24 nonce);

    /// @notice Thrown when the withdraw lock period exceeds the maximum allowed value.
    error WithdrawLockPeriodTooHigh(uint32 withdrawLockPeriod, uint32 maxWithdrawLockPeriod);

    /// @notice Thrown when trying to finalize a withdrawal while in debt.
    error PayerInDebt();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when any pausable function is called when the contract is paused.
    error Paused();

    /// @notice Thrown when there is no excess fee tokens to transfer to the fee distributor.
    error NoExcess();

    /// @notice Thrown when the payer is the zero address.
    error ZeroPayer();

    /// @notice Thrown when the recipient is the zero address.
    error ZeroRecipient();

    /// @notice Thrown when the delegate address is zero.
    error ZeroDelegate();

    /// @notice Thrown when trying to authorize a delegate that is already authorized.
    error DelegationAlreadyExists();

    /// @notice Thrown when trying to revoke a delegation that does not exist.
    error DelegationDoesNotExist();

    /// @notice Thrown when the delegation expiry is in the past.
    error DelegationExpiryInPast();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits `amount_` fee tokens into the registry for `payer_`.
     * @param  payer_  The address of the payer.
     * @param  amount_ The amount of fee tokens to deposit.
     */
    function deposit(address payer_, uint96 amount_) external;

    /**
     * @notice Deposits `amount_` fee tokens into the registry for `payer_`, given caller's signed approval.
     * @param  payer_    The address of the payer.
     * @param  amount_   The amount of fee tokens to deposit.
     * @param  deadline_ The deadline of the permit (must be the current or future timestamp).
     * @param  v_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositWithPermit(
        address payer_,
        uint96 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Deposits `amount_` fee tokens into the registry for `payer_`, wrapping them from underlying fee tokens.
     * @param  payer_  The address of the payer.
     * @param  amount_ The amount of underlying fee tokens to deposit.
     */
    function depositFromUnderlying(address payer_, uint96 amount_) external;

    /**
     * @notice Deposits `amount_` fee tokens into the registry for `payer_`, wrapping them from underlying fee tokens,
     *         given caller's signed approval.
     * @param  payer_    The address of the payer.
     * @param  amount_   The amount of underlying fee tokens to deposit.
     * @param  deadline_ The deadline of the permit (must be the current or future timestamp).
     * @param  v_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s_        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function depositFromUnderlyingWithPermit(
        address payer_,
        uint96 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    /**
     * @notice Requests a withdrawal of `amount_` fee tokens.
     * @param  amount_ The amount of fee tokens to withdraw.
     * @dev    The caller must have enough balance to cover the withdrawal.
     */
    function requestWithdrawal(uint96 amount_) external;

    /// @notice Cancels a pending withdrawal of fee tokens, returning the amount to the balance.
    function cancelWithdrawal() external;

    /**
     * @notice Finalizes a pending withdrawal of fee tokens, transferring the amount to the recipient.
     * @param  recipient_ The address to receive the fee tokens.
     * @dev    The caller must not be currently in debt.
     */
    function finalizeWithdrawal(address recipient_) external;

    /**
     * @notice Finalizes a pending withdrawal of fee tokens, unwrapping the amount into underlying fee tokens to the
     *         recipient.
     * @param  recipient_ The address to receive the underlying fee tokens.
     * @dev    The caller must not be currently in debt.
     */
    function finalizeWithdrawalIntoUnderlying(address recipient_) external;

    /**
     * @notice Settles the usage fees for a list of payers.
     * @param  payerReportId_ The ID of the payer report triggering the settlement.
     * @param  payerFees_   An array of structs containing the payer and the fee to settle.
     * @return feesSettled_ The total amount of fees settled.
     */
    function settleUsage(bytes32 payerReportId_, PayerFee[] calldata payerFees_) external returns (uint96 feesSettled_);

    /**
     * @notice Sends the excess tokens in the contract to the fee distributor.
     * @return excess_ The amount of excess tokens sent to the fee distributor.
     */
    function sendExcessToFeeDistributor() external returns (uint96 excess_);

    /**
     * @notice Updates the settler of the contract.
     * @dev    Ensures the new settler is not zero (i.e. address(0)).
     */
    function updateSettler() external;

    /**
     * @notice Updates the fee distributor of the contract.
     * @dev    Ensures the new fee distributor is not zero (i.e. address(0)).
     */
    function updateFeeDistributor() external;

    /**
     * @notice Updates the minimum deposit amount.
     * @dev    Ensures the new minimum deposit is not zero (i.e. address(0)).
     */
    function updateMinimumDeposit() external;

    /// @notice Updates the withdraw lock period.
    function updateWithdrawLockPeriod() external;

    /// @notice Updates the pause status.
    function updatePauseStatus() external;

    /* ============ Delegation Functions ============ */

    /**
     * @notice Authorizes a delegate to sign payer envelopes on behalf of the caller.
     * @param  delegate_ The address of the delegate (e.g., gateway) to authorize.
     * @param  expiry_   The timestamp when the delegation expires (0 for no expiry).
     */
    function authorize(address delegate_, uint64 expiry_) external;

    /**
     * @notice Revokes a delegate's authorization to sign on behalf of the caller.
     * @param  delegate_ The address of the delegate to revoke.
     */
    function revoke(address delegate_) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the settler.
    function settlerParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the fee distributor.
    function feeDistributorParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the minimum deposit.
    function minimumDepositParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the withdraw lock period.
    function withdrawLockPeriodParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the fee token contract used for deposits and withdrawals.
    function feeToken() external view returns (address feeToken_);

    /// @notice The address of the settler that can call `settleUsage`.
    function settler() external view returns (address settler_);

    /// @notice The address of the fee distributor that receives unencumbered fees from usage settlements.
    function feeDistributor() external view returns (address feeDistributor_);

    /// @notice The sum of all payer balances and pending withdrawals.
    function totalDeposits() external view returns (int104 totalDeposits_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);

    /// @notice The sum of all payer debts.
    function totalDebt() external view returns (uint96 totalDebt_);

    /// @notice The sum of all withdrawable balances (sum of all positive payer balances and pending withdrawals).
    function totalWithdrawable() external view returns (uint96 totalWithdrawable_);

    /// @notice The minimum amount required for any deposit.
    function minimumDeposit() external view returns (uint96 minimumDeposit_);

    /// @notice The withdraw lock period.
    function withdrawLockPeriod() external view returns (uint32 withdrawLockPeriod_);

    /// @notice The amount of excess tokens in the contract that are not withdrawable by payers.
    function excess() external view returns (uint96 excess_);

    /**
     * @notice Returns the balance of a payer.
     * @param  payer_   The address of the payer.
     * @return balance_ The signed balance of the payer (negative if debt).
     */
    function getBalance(address payer_) external view returns (int104 balance_);

    /**
     * @notice Returns the balances of an array of payers.
     * @dev    This is a periphery function for nodes, and is not required for the core protocol.
     * @param  payers_   An array of payer addresses.
     * @return balances_ The signed balances of each payer (negative if debt).
     */
    function getBalances(address[] calldata payers_) external view returns (int104[] memory balances_);

    /**
     * @notice Returns the pending withdrawal of a payer.
     * @param  payer_                 The address of the payer.
     * @return pendingWithdrawal_     The amount of a pending withdrawal, if any.
     * @return withdrawableTimestamp_ The timestamp when the pending withdrawal can be finalized.
     * @return nonce_                 The nonce associated with the pending withdrawal.
     */
    function getPendingWithdrawal(
        address payer_
    ) external view returns (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_, uint24 nonce_);

    /**
     * @notice Checks if a delegate is authorized to sign on behalf of a payer.
     * @param  payer_        The address of the payer.
     * @param  delegate_     The address of the delegate.
     * @return isAuthorized_ True if the delegate is authorized and delegation has not expired.
     */
    function isAuthorized(address payer_, address delegate_) external view returns (bool isAuthorized_);

    /**
     * @notice Returns the delegation information for a payer and delegate.
     * @param  payer_      The address of the payer.
     * @param  delegate_   The address of the delegate.
     * @return delegation_ The delegation struct with isActive, expiry, and createdAt.
     */
    function getDelegation(address payer_, address delegate_) external view returns (Delegation memory delegation_);
}
