// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC165 } from "../../lib/oz/contracts/utils/introspection/IERC165.sol";

/**
 * @title  IPayerRegistryEvents
 * @notice Interface for events emitted by the PayerRegistry contract.
 */
interface IPayerRegistryEvents {
    /// @dev Emitted when the fee distributor address is updated.
    event FeeDistributorSet(address indexed newFeeDistributor);

    /// @dev Emitted when fees are transferred to the distribution contract.
    event FeesTransferred(uint64 indexed timestamp, uint64 amount);

    /// @dev Emitted when the minimum deposit amount is updated.
    event MinimumDepositSet(uint64 oldMinimumDeposit, uint64 newMinimumDeposit);

    /// @dev Emitted when the minimum registration amount is updated.
    event MinimumRegistrationAmountSet(uint64 oldMinimumRegistrationAmount, uint64 newMinimumRegistrationAmount);

    /// @dev Emitted when the node registry address is updated.
    event NodeRegistrySet(address indexed newNodeRegistry);

    /// @dev Emitted when a payer balance is updated.
    event PayerBalanceUpdated(address indexed payer, int64 newBalance);

    /// @dev Emitted when a payer is deactivated by an owner.
    event PayerDeactivated(uint256 indexed operatorId, address indexed payer);

    /// @dev Emitted when a new payer is registered.
    event PayerRegistered(address indexed payer, uint64 amount);

    /// @dev Emitted when the payer report manager address is updated.
    event PayerReportManagerSet(address indexed newPayerReportManager);

    /// @dev Emitted when the transfer fees period is updated.
    event TransferFeesPeriodSet(uint32 oldTransferFeesPeriod, uint32 newTransferFeesPeriod);

    /// @dev Emitted when the upgrade is authorized.
    event UpgradeAuthorized(address indexed upgrader, address indexed newImplementation);

    /// @dev Emitted when usage is settled and fees are calculated.
    event UsageSettled(uint256 indexed originatorNode, uint64 timestamp, uint64 collectedFees);

    /// @dev Emitted when the USDC token address is updated.
    event UsdcTokenSet(address indexed newUsdcToken);

    /// @dev Emitted when a payer cancels a withdrawal request.
    event WithdrawalCancelled(address indexed payer, uint64 indexed withdrawableTimestamp);

    /// @dev Emitted when a payer's withdrawal is finalized.
    event WithdrawalFinalized(address indexed payer, uint64 indexed withdrawableTimestamp, uint64 amount);

    /// @dev Emitted when the withdrawal lock period is updated.
    event WithdrawalLockPeriodSet(uint32 oldWithdrawalLockPeriod, uint32 newWithdrawalLockPeriod);

    /// @dev Emitted when a payer initiates a withdrawal request.
    event WithdrawalRequested(address indexed payer, uint64 indexed withdrawableTimestamp, uint64 amount);
}

/**
 * @title  IPayerRegistryErrors
 * @notice Interface for errors emitted by the Payer contract.
 */
interface IPayerRegistryErrors {
    /// @dev Error thrown when arrays have mismatched lengths.
    error ArrayLengthMismatch();

    /// @notice Error thrown when adding a debtor has failed.
    error FailedToAddDebtor();

    /// @notice Error thrown when deactivating a payer has failed.
    error FailedToDeactivatePayer();

    /// @notice Error thrown when deleting a payer has failed.
    error FailedToDeletePayer();

    /// @notice Error thrown when granting a role has failed.
    error FailedToGrantRole(bytes32 role, address account);

    /// @notice Error thrown when registering a payer has failed.
    error FailedToRegisterPayer();

    /// @notice Error thrown when removing a debtor has failed.
    error FailedToRemoveDebtor();

    /// @dev Error thrown when an address is invalid (usually zero address).
    error InvalidAddress();

    /// @dev Error thrown when the amount is insufficient.
    error InsufficientAmount();

    /// @dev Error thrown when balance is insufficient.
    error InsufficientBalance();

    /// @dev Error thrown when insufficient time has passed since the last fee transfer.
    error InsufficientTimePassed();

    /// @dev Error thrown when contract is not the fee distributor.
    error InvalidFeeDistributor();

    /// @dev Error thrown when the minimum deposit is invalid.
    error InvalidMinimumDeposit();

    /// @dev Error thrown when the minimum registration amount is invalid.
    error InvalidMinimumRegistrationAmount();

    /// @dev Error thrown when contract is not the node registry.
    error InvalidNodeRegistry();

    /// @notice Error thrown when the payer list length is invalid.
    error InvalidPayerListLength();

    /// @dev Error thrown when contract is not the payer report manager.
    error InvalidPayerReportManager();

    /// @dev Error thrown when trying to backdate settlement too far.
    error InvalidSettlementTime();

    /// @dev Error thrown when the transfer fees period is invalid.
    error InvalidTransferFeesPeriod();

    /// @dev Error thrown when contract is not the USDC token contract.
    error InvalidUsdcTokenContract();

    /// @dev Error thrown when the withdrawal lock period is invalid.
    error InvalidWithdrawalLockPeriod();

    /// @dev Error thrown when a lock period has not yet elapsed.
    error LockPeriodNotElapsed();

    /// @notice Error thrown when the offset is out of bounds.
    error OutOfBounds();

    /// @dev Error thrown when payer already exists.
    error PayerAlreadyRegistered();

    /// @dev Error thrown when payer does not exist.
    error PayerDoesNotExist();

    /// @dev Error thrown when trying to delete a payer with balance or debt.
    error PayerHasBalanceOrDebt();

    /// @dev Error thrown when payer has debt.
    error PayerHasDebt();

    /// @dev Error thrown when trying to delete a payer in withdrawal state.
    error PayerInWithdrawal();

    /// @dev Error thrown when a payer is not active.
    error PayerIsNotActive();

    /// @dev Error thrown when a call is unauthorized.
    error Unauthorized();

    /// @dev Error thrown when caller is not an authorized node operator.
    error UnauthorizedNodeOperator();

    /// @dev Error thrown when a withdrawal is already in progress.
    error WithdrawalAlreadyRequested();

    /// @dev Error thrown when a withdrawal is not in the requested state.
    error WithdrawalNotExists();

    /// @dev Error thrown when a withdrawal is not in the requested state.
    error WithdrawalNotRequested();

    /// @dev Error thrown when a withdrawal lock period has not yet elapsed.
    error WithdrawalPeriodNotElapsed();
}

/**
 * @title  IPayerRegistry
 * @notice Interface for managing payer USDC deposits, usage settlements,
 *         and a secure withdrawal process.
 */
interface IPayerRegistry is IERC165, IPayerRegistryEvents, IPayerRegistryErrors {
    /* ============ Structs ============ */

    /**
     * @dev   Struct to store payer information.
     * @param balance                The current USDC balance of the payer.
     * @param latestDepositTimestamp The timestamp of the most recent deposit.
     */
    struct Payer {
        int64 balance;
        uint64 latestDepositTimestamp;
    }

    /**
     * @dev   Struct to store withdrawal request information.
     * @param withdrawableTimestamp The timestamp when the withdrawal can be finalized.
     * @param amount                The amount requested for withdrawal.
     */
    struct Withdrawal {
        uint64 withdrawableTimestamp;
        uint64 amount;
    }

    /* ============ Payer Management ============ */

    /**
     * @notice Registers the caller as a new payer upon depositing the minimum required USDC.
     *         The caller must approve this contract to spend USDC beforehand.
     * @param  amount The amount of USDC to deposit (must be at least the minimum required).
     *
     * Emits `PayerRegistered`.
     */
    function register(uint64 amount) external;

    /**
     * @notice Allows the caller to deposit USDC into their own payer account.
     *         The caller must approve this contract to spend USDC beforehand.
     * @param  amount The amount of USDC to deposit.
     *
     * Emits `PayerBalanceUpdated`.
     */
    function deposit(uint64 amount) external;

    /**
     * @notice Allows anyone to donate USDC to an existing payer's account.
     *         The sender must approve this contract to spend USDC beforehand.
     * @param  payer  The address of the payer receiving the donation.
     * @param  amount The amount of USDC to donate.
     *
     * Emits `PayerBalanceUpdated`.
     */
    function deposit(address payer, uint64 amount) external;

    /* ============ Payer Balance Management ============ */

    /**
     * @notice Initiates a withdrawal request for the caller.
     *         - Sets the payer into withdrawal mode (no further usage allowed).
     *         - Records a timestamp for the withdrawal lock period.
     * @param  amount The amount to withdraw (can be less than or equal to current balance).
     *
     * Emits `WithdrawalRequest`.
     * Emits `PayerBalanceUpdated`.
     */
    function requestWithdrawal(uint64 amount) external;

    /**
     * @notice Cancels a previously requested withdrawal, removing withdrawal mode.
     * @dev    Only callable by the payer who initiated the withdrawal.
     *
     * Emits `WithdrawalCancelled`.
     * Emits `PayerBalanceUpdated`.
     */
    function cancelWithdrawal() external;

    /**
     * @notice Finalizes a payer's withdrawal after the lock period has elapsed.
     *         - Accounts for any pending usage during the lock.
     *         - Returns the unspent balance to the payer.
     *
     * Emits `WithdrawalFinalized`.
     * Emits `PayerBalanceUpdated`.
     */
    function finalizeWithdrawal() external;

    /**
     * @notice Checks if a payer is currently in withdrawal mode and the timestamp
     *         when they initiated the withdrawal.
     * @param  payer                 The address to check.
     * @return withdrawal            The withdrawal status.
     */
    function getWithdrawalStatus(address payer) external view returns (Withdrawal memory withdrawal);

    /* ============ Usage Settlement ============ */

    /**
     * @notice Settles usage for a contiguous batch of (payer, amount) entries.
     * Assumes that the PayerReport contract has already verified the validity of the payers and amounts.
     *
     * @param  originatorNode The originator node of the usage.
     * @param  payers         A contiguous array of payer addresses.
     * @param  amounts        A contiguous array of usage amounts corresponding to each payer.
     *
     * Emits `UsageSettled`.
     * Emits `PayerBalanceUpdated` for each payer.
     */
    function settleUsage(
        uint256 originatorNode,
        address[] calldata payers,
        uint64[] calldata amounts
    ) external; /* onlyPayerReport */

    /**
     * @notice Transfers all pending fees to the designated distribution contract.
     * @dev    Uses a single storage write for updating accumulated fees.
     *
     * Emits `FeesTransferred`.
     */
    function transferFeesToDistribution() external;

    /* ============ Administrative Functions ============ */

    /**
     * @notice Sets the address of the fee distributor.
     * @param  feeDistributor The address of the new fee distributor.
     *
     * Emits `FeeDistributorUpdated`.
     */
    function setFeeDistributor(address feeDistributor) external;

    /**
     * @notice Sets the address of the payer report manager.
     * @param  payerReportManager The address of the new payer report manager.
     *
     * Emits `PayerReportManagerUpdated`.
     */
    function setPayerReportManager(address payerReportManager) external;

    /**
     * @notice Sets the address of the node registry for operator verification.
     * @param  nodeRegistry The address of the new node registry.
     *
     * Emits `NodeRegistryUpdated`.
     */
    function setNodeRegistry(address nodeRegistry) external;

    /**
     * @notice Sets the address of the USDC token contract.
     * @param  usdcToken The address of the new USDC token contract.
     *
     * Emits `UsdcTokenUpdated`.
     */
    function setUsdcToken(address usdcToken) external;

    /**
     * @notice Sets the minimum deposit amount required for registration.
     * @param  newMinimumDeposit The new minimum deposit amount.
     *
     * Emits `MinimumDepositUpdated`.
     */
    function setMinimumDeposit(uint64 newMinimumDeposit) external;

    /**
     * @notice Sets the minimum deposit amount required for registration.
     * @param  newMinimumRegistrationAmount The new minimum deposit amount.
     *
     * Emits `MinimumRegistrationAmountUpdated`.
     */
    function setMinimumRegistrationAmount(uint64 newMinimumRegistrationAmount) external;

    /**
     * @notice Sets the withdrawal lock period.
     * @param  newWithdrawalLockPeriod The new withdrawal lock period.
     *
     * Emits `WithdrawalLockPeriodUpdated`.
     */
    function setWithdrawalLockPeriod(uint32 newWithdrawalLockPeriod) external;

    /**
     * @notice Sets the transfer fees period.
     * @param  newTransferFeesPeriod The new transfer fees period.
     *
     * Emits `TransferFeesPeriodUpdated`.
     */
    function setTransferFeesPeriod(uint32 newTransferFeesPeriod) external;

    /**
     * @notice Pauses the contract functions in case of emergency.
     *
     * Emits `Paused()`.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract.
     *
     * Emits `Unpaused()`.
     */
    function unpause() external;

    /* ============ Getters ============ */

    /**
     * @notice Returns the payer information.
     * @param  payer The address of the payer.
     * @return payerInfo The payer information.
     */
    function getPayer(address payer) external view returns (Payer memory payerInfo);

    /**
     * @notice Returns all active payers in a paginated response.
     * @param  offset Number of payers to skip before starting to return results.
     * @param  limit  Maximum number of payers to return.
     * @return payers The payer information.
     * @return hasMore True if there are more payers to retrieve.
     */
    function getActivePayers(uint32 offset, uint32 limit) external view returns (Payer[] memory payers, bool hasMore);

    /**
     * @notice Checks if a given address is an active payer.
     * @param  payer    The address to check.
     * @return isActive True if the address is an active payer, false otherwise.
     */
    function getIsActivePayer(address payer) external view returns (bool isActive);

    /**
     * @notice Returns a paginated list of payers with outstanding debt.
     * @param  offset      Number of payers to skip before starting to return results.
     * @param  limit       Maximum number of payers to return.
     * @return payers      Array of payer addresses with debt.
     * @return hasMore     True if there are more payers to retrieve.
     */
    function getPayersInDebt(uint32 offset, uint32 limit) external view returns (Payer[] memory payers, bool hasMore);

    /**
     * @notice Returns the timestamp of the last fee transfer to the rewards contract.
     * @return timestamp The last fee transfer timestamp.
     */
    function getLastFeeTransferTimestamp() external view returns (uint64 timestamp);

    /**
     * @notice Returns the actual USDC balance held by the contract.
     * @dev    This can be used to verify the contract's accounting is accurate.
     * @return balance The USDC token balance of the contract.
     */
    function getContractBalance() external view returns (uint256 balance);

    /**
     * @notice Retrieves the address of the current distribution contract.
     * @return feeDistributor The address of the fee distributor.
     */
    function getFeeDistributor() external view returns (address feeDistributor);

    /**
     * @notice Retrieves the address of the current nodes contract.
     * @return nodeRegistry The address of the node registry.
     */
    function getNodeRegistry() external view returns (address nodeRegistry);

    /**
     * @notice Retrieves the address of the current payer report manager.
     * @return payerReportManager The address of the payer report manager.
     */
    function getPayerReportManager() external view returns (address payerReportManager);

    /**
     * @notice Retrieves the minimum deposit amount required to register as a payer.
     * @return minimumDeposit The minimum deposit amount in USDC.
     */
    function getMinimumDeposit() external view returns (uint64 minimumDeposit);

    /**
     * @notice Retrieves the minimum deposit amount required to register as a payer.
     * @return minimumRegistrationAmount The minimum deposit amount in USDC.
     */
    function getMinimumRegistrationAmount() external view returns (uint64 minimumRegistrationAmount);

    /**
     * @notice Retrieves the current total balance of a given payer.
     * @param  payer   The address of the payer.
     * @return balance The current balance of the payer.
     */
    function getPayerBalance(address payer) external view returns (int64 balance);

    /**
     * @notice Returns the duration of the lock period required before a withdrawal
     *         can be finalized.
     * @return lockPeriod The lock period in seconds.
     */
    function getWithdrawalLockPeriod() external view returns (uint32 lockPeriod);

    /**
     * @notice Retrieves the total pending fees that have not yet been transferred
     *         to the distribution contract.
     * @return fees The total pending fees in USDC.
     */
    function getPendingFees() external view returns (uint64 fees);
}
