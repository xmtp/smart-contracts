// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPayerRegistry {
    /* ============ Structs ============ */

    /**
     * @notice Represents a payer in the registry.
     * @param  balance               The signed balance of the payer (negative if debt).
     * @param  pendingWithdrawal     The amount of a pending withdrawal, if any.
     * @param  withdrawableTimestamp The timestamp when the pending withdrawal can be finalized.
     */
    struct Payer {
        int104 balance;
        uint96 pendingWithdrawal;
        uint32 withdrawableTimestamp;
        // 24 bits remaining in first slot
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when the admin is set.
     * @param  admin The address of the new admin.
     */
    event AdminSet(address indexed admin);

    /**
     * @notice Emitted when the settler is set.
     * @param  settler The address of the new settler.
     */
    event SettlerSet(address indexed settler);

    /**
     * @notice Emitted when the fee distributor is set.
     * @param  feeDistributor The address of the new fee distributor.
     */
    event FeeDistributorSet(address indexed feeDistributor);

    /**
     * @notice Emitted when the minimum deposit is set.
     * @param  minimumDeposit The new minimum deposit amount.
     */
    event MinimumDepositSet(uint96 minimumDeposit);

    /**
     * @notice Emitted when the withdraw lock period is set.
     * @param  withdrawLockPeriod The new withdraw lock period.
     */
    event WithdrawLockPeriodSet(uint32 withdrawLockPeriod);

    /**
     * @notice Emitted when a deposit of tokens occurs for a payer.
     * @param  payer  The address of the payer.
     * @param  amount The amount of tokens deposited.
     */
    event Deposit(address indexed payer, uint96 amount);

    /**
     * @notice Emitted when a withdrawal is requested by a payer.
     * @param  payer                 The address of the payer.
     * @param  amount                The amount of tokens requested for withdrawal.
     * @param  withdrawableTimestamp The timestamp when the withdrawal can be finalized.
     */
    event WithdrawalRequested(address indexed payer, uint96 amount, uint32 withdrawableTimestamp);

    /**
     * @notice Emitted when a payer's pending withdrawal is cancelled.
     * @param  payer The address of the payer.
     */
    event WithdrawalCancelled(address indexed payer);

    /**
     * @notice Emitted when a payer's pending withdrawal is finalized.
     * @param  payer The address of the payer.
     */
    event WithdrawalFinalized(address indexed payer);

    /**
     * @notice Emitted when a payer's usage is settled.
     * @param  payer  The address of the payer.
     * @param  amount The amount of tokens settled (the fee deducted form their balance).
     */
    event UsageSettled(address indexed payer, uint96 amount);

    /**
     * @notice Emitted when fees are transferred to the fee distributor.
     * @param  amount The amount of tokens transferred.
     */
    event FeesTransferred(uint96 amount);

    /* ============ Custom Errors ============ */

    /// @notice Error thrown when caller is not the admin.
    error NotAdmin();

    /// @notice Error thrown when caller is not the settler.
    error NotSettler();

    /// @notice Error thrown when the token address is being set to 0x0.
    error ZeroTokenAddress();

    /// @notice Error thrown when the admin address is being set to 0x0.
    error ZeroAdminAddress();

    /// @notice Error thrown when the settler address is being set to 0x0.
    error ZeroSettlerAddress();

    /// @notice Error thrown when the fee distributor address is being set to 0x0.
    error ZeroFeeDistributorAddress();

    /// @notice Error thrown when the implementation address is being set to 0x0.
    error ZeroImplementationAddress();

    /// @notice Error thrown when a `transfer` of tokens fails.
    error ERC20TransferFailed();

    /// @notice Error thrown when a `transferFrom` of tokens fails.
    error ERC20TransferFromFailed();

    /**
     * @notice Error thrown when the deposit amount is less than the minimum deposit.
     * @param  amount         The amount of tokens being deposited.
     * @param  minimumDeposit The minimum deposit amount.
     */
    error InsufficientDeposit(uint96 amount, uint96 minimumDeposit);

    /// @notice Error thrown when a payer has insufficient balance for a withdrawal request.
    error InsufficientBalance();

    /// @notice Error thrown when for a withdrawal request of 0.
    error ZeroWithdrawalAmount();

    /// @notice Error thrown when a withdrawal is pending for a payer.
    error PendingWithdrawalExists();

    /// @notice Error thrown when a withdrawal is not pending for a payer.
    error NoPendingWithdrawal();

    /**
     * @notice Error thrown when trying to finalize a withdrawal before the withdraw lock period has passed.
     * @param  timestamp             The current timestamp.
     * @param  withdrawableTimestamp The timestamp when the withdrawal can be finalized.
     */
    error WithdrawalNotReady(uint32 timestamp, uint32 withdrawableTimestamp);

    /// @notice Error thrown when the lengths or array arguments do not match.
    error ArrayLengthMismatch();

    /// @notice Error thrown when trying to finalize a withdrawal while in debt.
    error PayerInDebt();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     * @param  admin_              The address of the admin.
     * @param  settler_            The address of the settler.
     * @param  feeDistributor_     The address of the fee distributor.
     * @param  minimumDeposit_     The minimum deposit amount.
     * @param  withdrawLockPeriod_ The withdraw lock period.
     */
    function initialize(
        address admin_,
        address settler_,
        address feeDistributor_,
        uint96 minimumDeposit_,
        uint32 withdrawLockPeriod_
    ) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deposits `amount` tokens into the registry for `payer`.
     * @param  payer_  The address of the payer.
     * @param  amount_ The amount of tokens to deposit.
     */
    function deposit(address payer_, uint96 amount_) external;

    /**
     * @notice Deposits `amount` tokens into the registry.
     * @param  amount_ The amount of tokens to deposit.
     */
    function deposit(uint96 amount_) external;

    /**
     * @notice Requests a withdrawal of `amount` tokens.
     * @param  amount_ The amount of tokens to withdraw.
     */
    function requestWithdrawal(uint96 amount_) external;

    /// @notice Cancels a pending withdrawal of tokens, returning the amount to the balance.
    function cancelWithdrawal() external;

    /**
     * @notice Finalizes a pending withdrawal of tokens, transferring the amount to the recipient.
     * @param  recipient_ The address to receive the withdrawn tokens.
     */
    function finalizeWithdrawal(address recipient_) external;

    /**
     * @notice Settles the usage fees for a list of payers.
     * @param  payers_ The addresses of the payers.
     * @param  fees_   The fees to settle for each payer.
     */
    function settleUsage(address[] calldata payers_, uint96[] calldata fees_) external;

    /* ============ Admin functionality ============ */

    /// @notice Pauses the contract, restricting certain actions.
    function pause() external;

    /// @notice Unpauses the contract, allowing normal operations.
    function unpause() external;

    /**
     * @notice Sets the admin of the contract.
     * @param  newAdmin_ The address of the new admin.
     */
    function setAdmin(address newAdmin_) external;

    /**
     * @notice Sets the settler of the contract.
     * @param  newSettler_ The address of the new settler.
     */
    function setSettler(address newSettler_) external;

    /**
     * @notice Sets the fee distributor of the contract.
     * @param  newFeeDistributor_ The address of the new fee distributor.
     */
    function setFeeDistributor(address newFeeDistributor_) external;

    /**
     * @notice Sets the minimum deposit amount.
     * @param  newMinimumDeposit_ The new minimum deposit amount.
     */
    function setMinimumDeposit(uint96 newMinimumDeposit_) external;

    /**
     * @notice Sets the withdraw lock period.
     * @param  newWithdrawLockPeriod_ The new withdraw lock period.
     */
    function setWithdrawLockPeriod(uint32 newWithdrawLockPeriod_) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The address of the token contract used for deposits and withdrawals.
    function token() external view returns (address token_);

    /// @notice The address of the admin that can call admin functions.
    function admin() external view returns (address admin_);

    /// @notice The address of the settler that can call `settleUsage`.
    function settler() external view returns (address settler_);

    /// @notice The address of the fee distributor that receives unencumbered fees from usage settlements.
    function feeDistributor() external view returns (address feeDistributor_);

    /// @notice The sum of all payer balances and pending withdrawals.
    function totalDeposits() external view returns (int104 totalDeposits_);

    /// @notice The sum of all payer debts.
    function totalDebt() external view returns (uint96 totalDebt_);

    /// @notice The sum of all withdrawable balances (sum of all positive payer balances and pending withdrawals).
    function totalWithdrawable() external view returns (uint96 totalWithdrawable_);

    /// @notice The minimum amount required for any deposit.
    function minimumDeposit() external view returns (uint96 minimumDeposit_);

    /// @notice The withdraw lock period.
    function withdrawLockPeriod() external view returns (uint32 withdrawLockPeriod_);

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
     * @param  payer_             The address of the payer.
     * @return pendingWithdrawal_ The amount of a pending withdrawal, if any.
     */
    function getPendingWithdrawal(address payer_) external view returns (uint96 pendingWithdrawal_);

    /**
     * @notice Returns the timestamp when a pending withdrawal can be finalized.
     * @param  payer_                 The address of the payer.
     * @return withdrawableTimestamp_ The timestamp when the pending withdrawal can be finalized.
     */
    function getWithdrawableTimestamp(address payer_) external view returns (uint32 withdrawableTimestamp_);
}
