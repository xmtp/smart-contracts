// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlUpgradeable } from "../lib/oz-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { EnumerableSet } from "../lib/oz/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "../lib/oz/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "../lib/oz/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC165 } from "../lib/oz/contracts/utils/introspection/IERC165.sol";
import { Initializable } from "../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "../lib/oz-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "../lib/oz-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "../lib/oz/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "../lib/oz-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IFeeDistributor } from "./interfaces/IFeeDistributor.sol";
import { INodes } from "./interfaces/INodes.sol";
import { IPayerRegistry } from "./interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "./interfaces/IPayerReportManager.sol";

/**
 * @title  PayerRegistry
 * @notice Implementation for managing payer USDC deposits, usage settlements,
 *         and a secure withdrawal process.
 */
contract PayerRegistry is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IPayerRegistry
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ============ Constants ============ */

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    string internal constant _USDC_SYMBOL = "USDC";
    uint8 private constant _PAYER_OPERATOR_ID = 1;
    uint64 private constant _DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint64 private constant _DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint64 private constant _DEFAULT_MAX_TOLERABLE_DEBT_AMOUNT_MICRO_DOLLARS = 50_000_000;
    uint32 private constant _DEFAULT_MINIMUM_TRANSFER_FEES_PERIOD = 6 hours;
    uint32 private constant _ABSOLUTE_MINIMUM_TRANSFER_FEES_PERIOD = 1 hours;
    uint32 private constant _DEFAULT_WITHDRAWAL_LOCK_PERIOD = 3 days;
    uint32 private constant _ABSOLUTE_MINIMUM_WITHDRAWAL_LOCK_PERIOD = 1 days;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.Payer
    struct PayerStorage {
        // Configuration and state parameters (fits in 2 slots)
        uint64 minimumRegistrationAmountMicroDollars;
        uint64 minimumDepositAmountMicroDollars;
        uint64 maxTolerableDebtAmountMicroDollars;
        uint64 lastFeeTransferTimestamp;
        uint64 totalDeposited;
        uint64 totalDebt;
        uint64 pendingFees;
        uint64 collectedFees;
        uint32 withdrawalLockPeriod;
        uint32 transferFeesPeriod;
        // Contract addresses (fits in 3 slots)
        address usdcToken;
        address feeDistributor;
        address nodeRegistry;
        address payerReportManager;
        // Mappings and dynamic sets (each starts at its own storage slot)
        mapping(address => Payer) payers;
        mapping(address => Withdrawal) withdrawals;
        EnumerableSet.AddressSet totalPayers;
        EnumerableSet.AddressSet activePayers;
        EnumerableSet.AddressSet debtPayers;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.Payer")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PAYER_STORAGE_LOCATION =
        0xd0335f337c570f3417b0f0d20340c88da711d60e810b5e9b3ecabe9ccfcdce5a;

    function _getPayerStorage() internal pure returns (PayerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PAYER_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    /**
     * @dev Modifier to check if caller is the payer report contract.
     */
    modifier onlyPayerReport() {
        require(msg.sender == _getPayerStorage().payerReportManager, Unauthorized());
        _;
    }

    /**
     * @dev Modifier to check if address is an active payer.
     */
    modifier onlyPayer(address payer) {
        require(_payerExists(msg.sender), PayerDoesNotExist());
        _;
    }

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract with the deployer as admin.
     * @param  initialAdmin The address of the admin.
     * @dev    There's a chicken-egg problem here with PayerReport and Distribution contracts.
     *         We need to deploy these contracts first, then set their addresses
     *         in the Payer contract.
     */
    function initialize(address initialAdmin, address usdcToken, address nodesContract) public initializer {
        if (initialAdmin == address(0) || usdcToken == address(0) || nodesContract == address(0)) {
            revert InvalidAddress();
        }

        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        PayerStorage storage $ = _getPayerStorage();

        $.minimumRegistrationAmountMicroDollars = _DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS;
        $.minimumDepositAmountMicroDollars = _DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS;
        $.withdrawalLockPeriod = _DEFAULT_WITHDRAWAL_LOCK_PERIOD;
        $.maxTolerableDebtAmountMicroDollars = _DEFAULT_MAX_TOLERABLE_DEBT_AMOUNT_MICRO_DOLLARS;
        $.transferFeesPeriod = _DEFAULT_MINIMUM_TRANSFER_FEES_PERIOD;

        _setUsdcToken(usdcToken);
        _setNodeRegistry(nodesContract);

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
    }

    /* ============ Payers Management ============ */

    /**
     * @inheritdoc IPayerRegistry
     */
    function register(uint64 amount) external whenNotPaused {
        PayerStorage storage $ = _getPayerStorage();

        require(amount >= $.minimumRegistrationAmountMicroDollars, InsufficientAmount());

        if (_payerExists(msg.sender)) revert PayerAlreadyRegistered();

        IERC20($.usdcToken).safeTransferFrom(msg.sender, address(this), amount);

        // New payer registration
        $.payers[msg.sender] = Payer({
            balance: amount,
            debtAmount: 0,
            latestDepositTimestamp: uint64(block.timestamp)
        });

        // Add new payer to active and total payers sets
        require($.activePayers.add(msg.sender), FailedToRegisterPayer());
        require($.totalPayers.add(msg.sender), FailedToRegisterPayer());

        _increaseTotalDeposited(amount);

        emit PayerRegistered(msg.sender, amount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function deposit(uint64 amount) external whenNotPaused nonReentrant onlyPayer(msg.sender) {
        _validateAndProcessDeposit(msg.sender, msg.sender, amount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function deposit(address payer, uint64 amount) external whenNotPaused {
        _revertIfPayerDoesNotExist(payer);

        _validateAndProcessDeposit(msg.sender, payer, amount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function deactivatePayer(uint256 nodeId, address payer) external whenNotPaused {
        _revertIfPayerDoesNotExist(payer);

        _deactivatePayer(nodeId, payer);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function deletePayer(address payer) external whenNotPaused onlyRole(ADMIN_ROLE) {
        _revertIfPayerDoesNotExist(payer);

        PayerStorage storage $ = _getPayerStorage();

        require($.withdrawals[payer].withdrawableTimestamp == 0, PayerInWithdrawal());

        if ($.payers[payer].balance > 0 || $.payers[payer].debtAmount > 0) {
            revert PayerHasBalanceOrDebt();
        }

        // Delete all payer data
        delete $.payers[payer];
        require($.totalPayers.remove(payer), FailedToDeletePayer());
        require($.activePayers.remove(payer), FailedToDeletePayer());

        emit PayerDeleted(payer, uint64(block.timestamp));
    }

    /* ========== Payers Balance Management ========= */

    /**
     * @inheritdoc IPayerRegistry
     */
    function requestWithdrawal(uint64 amount) external whenNotPaused onlyPayer(msg.sender) {
        if (_withdrawalExists(msg.sender)) revert WithdrawalAlreadyRequested();

        PayerStorage storage $ = _getPayerStorage();

        require($.payers[msg.sender].debtAmount == 0, PayerHasDebt());
        require($.payers[msg.sender].balance >= amount, InsufficientBalance());

        // Balance to be withdrawn is deducted from the payer's balance,
        // it can't be used to settle payments.
        $.payers[msg.sender].balance -= amount;
        _decreaseTotalDeposited(amount);

        uint64 withdrawableTimestamp = uint64(block.timestamp) + $.withdrawalLockPeriod;

        $.withdrawals[msg.sender] = Withdrawal({ withdrawableTimestamp: withdrawableTimestamp, amount: amount });

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalRequested(msg.sender, withdrawableTimestamp, amount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function cancelWithdrawal() external whenNotPaused onlyPayer(msg.sender) {
        _revertIfWithdrawalNotExists(msg.sender);

        PayerStorage storage $ = _getPayerStorage();

        Withdrawal memory withdrawal = $.withdrawals[msg.sender];

        delete $.withdrawals[msg.sender];

        $.payers[msg.sender].balance += withdrawal.amount;
        _increaseTotalDeposited(withdrawal.amount);

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalCancelled(msg.sender, withdrawal.withdrawableTimestamp);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function finalizeWithdrawal() external whenNotPaused nonReentrant onlyPayer(msg.sender) {
        _revertIfWithdrawalNotExists(msg.sender);

        PayerStorage storage $ = _getPayerStorage();

        Withdrawal memory withdrawal = $.withdrawals[msg.sender];

        // slither-disable-next-line timestamp
        require(block.timestamp >= withdrawal.withdrawableTimestamp, WithdrawalPeriodNotElapsed());

        delete $.withdrawals[msg.sender];

        uint64 finalWithdrawalAmount = withdrawal.amount;

        if ($.payers[msg.sender].debtAmount > 0) {
            finalWithdrawalAmount = _settleDebts(msg.sender, withdrawal.amount, true);
        }

        if (finalWithdrawalAmount > 0) {
            IERC20($.usdcToken).safeTransfer(msg.sender, finalWithdrawalAmount);
        }

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalFinalized(msg.sender, withdrawal.withdrawableTimestamp, finalWithdrawalAmount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getWithdrawalStatus(address payer) external view returns (Withdrawal memory withdrawal) {
        _revertIfPayerDoesNotExist(payer);

        return _getPayerStorage().withdrawals[payer];
    }

    /* ============ Usage Settlement ============ */

    /**
     * @inheritdoc IPayerRegistry
     */
    function settleUsage(
        uint256 originatorNode,
        address[] calldata payerList,
        uint64[] calldata usageAmountsList
    ) external whenNotPaused nonReentrant onlyPayerReport {
        require(payerList.length == usageAmountsList.length, InvalidPayerListLength());

        PayerStorage storage $ = _getPayerStorage();

        uint64 settledFees = 0;
        uint64 pendingFees = $.pendingFees;

        for (uint256 i = 0; i < payerList.length; i++) {
            address payer = payerList[i];
            uint64 usage = usageAmountsList[i];

            // This should never happen, as PayerReport has already verified the payers and amounts.
            // Payers in payerList should always exist and be active.
            if (!_payerExists(payer) || !_payerIsActive(payer)) continue;

            Payer memory storedPayer = $.payers[payer];

            if (storedPayer.balance < usage) {
                uint64 debt = usage - storedPayer.balance;

                settledFees += storedPayer.balance;
                pendingFees += storedPayer.balance;

                storedPayer.balance = 0;
                storedPayer.debtAmount = debt;
                $.payers[payer] = storedPayer;

                _addDebtor(payer);
                _increaseTotalDebt(debt);

                if (debt > $.maxTolerableDebtAmountMicroDollars) _deactivatePayer(_PAYER_OPERATOR_ID, payer);

                emit PayerBalanceUpdated(payer, storedPayer.balance, storedPayer.debtAmount);

                continue;
            }

            settledFees += usage;
            pendingFees += usage;

            storedPayer.balance -= usage;

            $.payers[payer] = storedPayer;

            emit PayerBalanceUpdated(payer, storedPayer.balance, storedPayer.debtAmount);
        }

        $.pendingFees = pendingFees;

        emit UsageSettled(originatorNode, uint64(block.timestamp), settledFees);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function transferFeesToDistribution() external whenNotPaused nonReentrant {
        PayerStorage storage $ = _getPayerStorage();

        /// @dev slither marks this as a security issue because validators can modify block.timestamp.
        ///      However, in this scenario it's fine, as we'd just send fees a earlier than expected.
        ///      It would be a bigger issue if we'd rely on timestamp for randomness or calculations.
        // slither-disable-next-line timestamp
        require(block.timestamp - $.lastFeeTransferTimestamp >= $.transferFeesPeriod, InsufficientTimePassed());

        uint64 pendingFeesAmount = $.pendingFees;

        require(pendingFeesAmount > 0, InsufficientAmount());

        IERC20($.usdcToken).safeTransfer($.feeDistributor, pendingFeesAmount);

        $.lastFeeTransferTimestamp = uint64(block.timestamp);
        $.collectedFees += pendingFeesAmount;
        $.pendingFees = 0;

        emit FeesTransferred(uint64(block.timestamp), pendingFeesAmount);
    }

    /* ========== Administrative Functions ========== */

    /**
     * @inheritdoc IPayerRegistry
     */
    function setFeeDistributor(address newFeeDistributor) external onlyRole(ADMIN_ROLE) {
        _setFeeDistributor(newFeeDistributor);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setPayerReportManager(address newPayerReportManager) external onlyRole(ADMIN_ROLE) {
        _setPayerReportManager(newPayerReportManager);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setNodeRegistry(address newNodeRegistry) external onlyRole(ADMIN_ROLE) {
        _setNodeRegistry(newNodeRegistry);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setUsdcToken(address newUsdcToken) external onlyRole(ADMIN_ROLE) {
        _setUsdcToken(newUsdcToken);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setMinimumDeposit(uint64 newMinimumDeposit) external onlyRole(ADMIN_ROLE) {
        require(newMinimumDeposit > _DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS, InvalidMinimumDeposit());

        PayerStorage storage $ = _getPayerStorage();

        uint64 oldMinimumDeposit = $.minimumDepositAmountMicroDollars;
        $.minimumDepositAmountMicroDollars = newMinimumDeposit;

        emit MinimumDepositSet(oldMinimumDeposit, newMinimumDeposit);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setMinimumRegistrationAmount(uint64 newMinimumRegistrationAmount) external onlyRole(ADMIN_ROLE) {
        require(
            newMinimumRegistrationAmount > _DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS,
            InvalidMinimumRegistrationAmount()
        );

        PayerStorage storage $ = _getPayerStorage();

        uint64 oldMinimumRegistrationAmount = $.minimumRegistrationAmountMicroDollars;
        $.minimumRegistrationAmountMicroDollars = newMinimumRegistrationAmount;

        emit MinimumRegistrationAmountSet(oldMinimumRegistrationAmount, newMinimumRegistrationAmount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setWithdrawalLockPeriod(uint32 newWithdrawalLockPeriod) external onlyRole(ADMIN_ROLE) {
        require(newWithdrawalLockPeriod >= _ABSOLUTE_MINIMUM_WITHDRAWAL_LOCK_PERIOD, InvalidWithdrawalLockPeriod());

        PayerStorage storage $ = _getPayerStorage();

        uint32 oldWithdrawalLockPeriod = $.withdrawalLockPeriod;
        $.withdrawalLockPeriod = newWithdrawalLockPeriod;

        emit WithdrawalLockPeriodSet(oldWithdrawalLockPeriod, newWithdrawalLockPeriod);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setMaxTolerableDebtAmount(uint64 newMaxTolerableDebtAmountMicroDollars) external onlyRole(ADMIN_ROLE) {
        require(newMaxTolerableDebtAmountMicroDollars > 0, InvalidMaxTolerableDebtAmount());

        PayerStorage storage $ = _getPayerStorage();

        uint64 oldMaxTolerableDebtAmount = $.maxTolerableDebtAmountMicroDollars;
        $.maxTolerableDebtAmountMicroDollars = newMaxTolerableDebtAmountMicroDollars;

        emit MaxTolerableDebtAmountSet(oldMaxTolerableDebtAmount, newMaxTolerableDebtAmountMicroDollars);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setTransferFeesPeriod(uint32 newTransferFeesPeriod) external onlyRole(ADMIN_ROLE) {
        require(newTransferFeesPeriod >= _ABSOLUTE_MINIMUM_TRANSFER_FEES_PERIOD, InvalidTransferFeesPeriod());

        PayerStorage storage $ = _getPayerStorage();

        uint32 oldTransferFeesPeriod = $.transferFeesPeriod;
        $.transferFeesPeriod = newTransferFeesPeriod;

        emit TransferFeesPeriodSet(oldTransferFeesPeriod, newTransferFeesPeriod);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /* ============ Getters ============ */

    /**
     * @inheritdoc IPayerRegistry
     */
    function getPayer(address payer) external view returns (Payer memory payerInfo) {
        _revertIfPayerDoesNotExist(payer);

        return _getPayerStorage().payers[payer];
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getActivePayers(uint32 offset, uint32 limit) external view returns (Payer[] memory payers, bool hasMore) {
        PayerStorage storage $ = _getPayerStorage();

        (address[] memory payerAddresses, bool hasMore_) = _getPaginatedAddresses($.activePayers, offset, limit);

        payers = new Payer[](payerAddresses.length);
        for (uint256 i = 0; i < payerAddresses.length; i++) {
            payers[i] = $.payers[payerAddresses[i]];
        }

        return (payers, hasMore_);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getIsActivePayer(address payer) public view returns (bool isActive) {
        _revertIfPayerDoesNotExist(payer);

        return _getPayerStorage().activePayers.contains(payer);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getPayerBalance(address payer) external view returns (uint64 balance) {
        _revertIfPayerDoesNotExist(payer);

        return _getPayerStorage().payers[payer].balance;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getPayersInDebt(uint32 offset, uint32 limit) external view returns (Payer[] memory payers, bool hasMore) {
        PayerStorage storage $ = _getPayerStorage();

        (address[] memory payerAddresses, bool hasMore_) = _getPaginatedAddresses($.debtPayers, offset, limit);

        payers = new Payer[](payerAddresses.length);
        for (uint256 i = 0; i < payerAddresses.length; i++) {
            payers[i] = $.payers[payerAddresses[i]];
        }

        return (payers, hasMore_);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getTotalPayerCount() external view returns (uint256 count) {
        return _getPayerStorage().totalPayers.length();
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getActivePayerCount() external view returns (uint256 count) {
        return _getPayerStorage().activePayers.length();
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getLastFeeTransferTimestamp() external view returns (uint64 timestamp) {
        return _getPayerStorage().lastFeeTransferTimestamp;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getTotalValueLocked() external view returns (uint64 totalValueLocked) {
        PayerStorage storage $ = _getPayerStorage();

        if ($.totalDebt > $.totalDeposited) return 0;

        return $.totalDeposited - $.totalDebt;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getTotalDebt() external view returns (uint64 totalDebt) {
        return _getPayerStorage().totalDebt;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getContractBalance() external view returns (uint256 balance) {
        return IERC20(_getPayerStorage().usdcToken).balanceOf(address(this));
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getFeeDistributor() external view returns (address feeDistributorAddress) {
        return _getPayerStorage().feeDistributor;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getNodeRegistry() external view returns (address nodeRegistryAddress) {
        return _getPayerStorage().nodeRegistry;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getPayerReportManager() external view returns (address payerReportManagerAddress) {
        return _getPayerStorage().payerReportManager;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getMinimumDeposit() external view returns (uint64 minimumDeposit) {
        return _getPayerStorage().minimumDepositAmountMicroDollars;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getMinimumRegistrationAmount() external view returns (uint64 minimumRegistrationAmount) {
        return _getPayerStorage().minimumRegistrationAmountMicroDollars;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getWithdrawalLockPeriod() external view returns (uint32 lockPeriod) {
        return _getPayerStorage().withdrawalLockPeriod;
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function getPendingFees() external view returns (uint64 fees) {
        return _getPayerStorage().pendingFees;
    }

    /* ============ Internal ============ */

    /**
     * @notice Validates and processes a deposit or donation
     * @param from The address funds are coming from
     * @param to The payer account receiving the deposit
     * @param amount The amount to deposit
     */
    function _validateAndProcessDeposit(address from, address to, uint64 amount) internal {
        PayerStorage storage $ = _getPayerStorage();

        require(amount >= $.minimumDepositAmountMicroDollars, InsufficientAmount());
        require($.withdrawals[to].withdrawableTimestamp == 0, PayerInWithdrawal());

        IERC20($.usdcToken).safeTransferFrom(from, address(this), amount);

        _updatePayerBalance(to, amount);

        emit PayerBalanceUpdated(to, $.payers[to].balance, $.payers[to].debtAmount);
    }

    /**
     * @notice Updates a payer's balance, handling debt settlement if applicable.
     * @param  payerAddress The address of the payer.
     * @param  amount The amount to add to the payer's balance.
     * @return leftoverAmount Amount remaining after debt settlement (if any).
     */
    function _updatePayerBalance(address payerAddress, uint64 amount) internal returns (uint64 leftoverAmount) {
        Payer storage payer = _getPayerStorage().payers[payerAddress];

        if (payer.debtAmount > 0) {
            return _settleDebts(payerAddress, amount, false);
        } else {
            payer.balance += amount;
            _increaseTotalDeposited(amount);
            return amount;
        }
    }

    /**
     * @notice Settles debts for a payer, updating their balance and total amounts.
     * @param  payer The address of the payer.
     * @param  amount The amount to settle debts for.
     * @param  isWithdrawal Whether the debt settlement happens during a withdrawal.
     * @return amountAfterSettlement The amount remaining after debt settlement.
     */
    function _settleDebts(
        address payer,
        uint64 amount,
        bool isWithdrawal
    ) internal returns (uint64 amountAfterSettlement) {
        PayerStorage storage $ = _getPayerStorage();

        Payer memory storedPayer = $.payers[payer];

        if (storedPayer.debtAmount < amount) {
            uint64 debtToRemove = storedPayer.debtAmount;
            amount -= debtToRemove;

            // For regular deposits, add remaining amount to balance.
            // In withdrawals, that amount was moved to the withdrawal balance.
            if (!isWithdrawal) {
                storedPayer.balance += amount;
                _increaseTotalDeposited(amount);
            }

            _removeDebtor(payer);
            _increaseTotalDeposited(amount);
            _decreaseTotalDebt(debtToRemove);

            amountAfterSettlement = amount;
        } else {
            storedPayer.debtAmount -= amount;

            _decreaseTotalDebt(amount);

            amountAfterSettlement = 0;
        }

        $.payers[payer] = storedPayer;

        return amountAfterSettlement;
    }

    /**
     * @notice Checks if a payer exists.
     * @param  payer The address of the payer to check.
     * @return exists True if the payer exists, false otherwise.
     */
    function _payerExists(address payer) internal view returns (bool exists) {
        return _getPayerStorage().payers[payer].latestDepositTimestamp != 0;
    }

    /**
     * @notice Checks if a payer is active.
     * @param  payer The address of the payer to check.
     * @return isActive True if the payer is active, false otherwise.
     */
    function _payerIsActive(address payer) internal view returns (bool isActive) {
        return _getPayerStorage().activePayers.contains(payer);
    }

    /**
     * @notice Deactivates a payer.
     * @param  payer The address of the payer to deactivate.
     */
    function _deactivatePayer(uint256 operatorId, address payer) internal {
        PayerStorage storage $ = _getPayerStorage();

        require($.activePayers.remove(payer), FailedToDeactivatePayer());

        emit PayerDeactivated(operatorId, payer);
    }

    /**
     * @notice Reverts if a payer does not exist.
     * @param  payer The address of the payer to check.
     */
    function _revertIfPayerDoesNotExist(address payer) internal view {
        require(_payerExists(payer), PayerDoesNotExist());
    }

    function _revertIfNotNodeOperator(uint256 nodeId) internal view {
        INodes nodes = INodes(_getPayerStorage().nodeRegistry);

        require(msg.sender == nodes.ownerOf(nodeId), Unauthorized());

        // TODO: Change for a better filter.
        return nodes.getReplicationNodeIsActive(nodeId);
    }

    /**
     * @notice Checks if a withdrawal exists.
     * @param  payer The address of the payer to check.
     * @return exists True if the withdrawal exists, false otherwise.
     */
    function _withdrawalExists(address payer) internal view returns (bool exists) {
        return _getPayerStorage().withdrawals[payer].withdrawableTimestamp != 0;
    }

    /**
     * @notice Reverts if a withdrawal does not exist.
     * @param  payer The address of the payer to check.
     */
    function _revertIfWithdrawalNotExists(address payer) internal view {
        require(_withdrawalExists(payer), WithdrawalNotExists());
    }

    /**
     * @notice Removes a payer from the debt payers set.
     * @param  payer The address of the payer to remove.
     */
    function _removeDebtor(address payer) internal {
        PayerStorage storage $ = _getPayerStorage();

        if ($.debtPayers.contains(payer)) {
            require($.debtPayers.remove(payer), FailedToRemoveDebtor());
        }
    }

    /**
     * @notice Adds a payer to the debt payers set.
     * @param  payer The address of the payer to add.
     */
    function _addDebtor(address payer) internal {
        PayerStorage storage $ = _getPayerStorage();

        if (!$.debtPayers.contains(payer)) {
            require($.debtPayers.add(payer), FailedToAddDebtor());
        }
    }

    /**
     * @notice Sets the FeeDistributor contract.
     * @param  newFeeDistributor The address of the new FeeDistributor contract.
     */
    function _setFeeDistributor(address newFeeDistributor) internal {
        PayerStorage storage $ = _getPayerStorage();

        try IFeeDistributor(newFeeDistributor).supportsInterface(type(IFeeDistributor).interfaceId) returns (
            bool supported
        ) {
            require(supported, InvalidFeeDistributor());
        } catch {
            revert InvalidFeeDistributor();
        }

        $.feeDistributor = newFeeDistributor;

        emit FeeDistributorSet(newFeeDistributor);
    }

    /**
     * @notice Sets the PayerReportManager contract.
     * @param  newPayerReportManager The address of the new PayerReportManager contract.
     */
    function _setPayerReportManager(address newPayerReportManager) internal {
        PayerStorage storage $ = _getPayerStorage();

        try
            IPayerReportManager(newPayerReportManager).supportsInterface(type(IPayerReportManager).interfaceId)
        returns (bool supported) {
            require(supported, InvalidPayerReportManager());
        } catch {
            revert InvalidPayerReportManager();
        }

        $.payerReportManager = newPayerReportManager;

        emit PayerReportManagerSet(newPayerReportManager);
    }

    /**
     * @notice Sets the NodeRegistry contract.
     * @param  newNodeRegistry The address of the new NodeRegistry contract.
     */
    function _setNodeRegistry(address newNodeRegistry) internal {
        PayerStorage storage $ = _getPayerStorage();

        try INodes(newNodeRegistry).supportsInterface(type(INodes).interfaceId) returns (bool supported) {
            require(supported, InvalidNodeRegistry());
        } catch {
            revert InvalidNodeRegistry();
        }

        $.nodeRegistry = newNodeRegistry;

        emit NodeRegistrySet(newNodeRegistry);
    }

    /**
     * @notice Sets the USDC token contract.
     * @param  newUsdcToken The address of the new USDC token contract.
     */
    function _setUsdcToken(address newUsdcToken) internal {
        PayerStorage storage $ = _getPayerStorage();

        try IERC20Metadata(newUsdcToken).symbol() returns (string memory symbol) {
            require(keccak256(bytes(symbol)) == keccak256(bytes(_USDC_SYMBOL)), InvalidUsdcTokenContract());
        } catch {
            revert InvalidUsdcTokenContract();
        }

        $.usdcToken = newUsdcToken;

        emit UsdcTokenSet(newUsdcToken);
    }

    /**
     * @notice Increases the total amount deposited by a given amount.
     * @param  amount The amount to increase the total amount deposited by.
     */
    function _increaseTotalDeposited(uint64 amount) internal {
        if (amount > 0) _getPayerStorage().totalDeposited += amount;
    }

    /**
     * @notice Decreases the total amount deposited by a given amount.
     * @param  amount The amount to decrease the total amount deposited by.
     */
    function _decreaseTotalDeposited(uint64 amount) internal {
        PayerStorage storage $ = _getPayerStorage();

        $.totalDeposited = amount > $.totalDeposited ? 0 : $.totalDeposited - amount;
    }

    /**
     * @notice Increases the total debt amount by a given amount.
     * @param  amount The amount to increase the total debt amount by.
     */
    function _increaseTotalDebt(uint64 amount) internal {
        _getPayerStorage().totalDebt += amount;
    }

    /**
     * @notice Decreases the total debt amount by a given amount.
     * @param  amount The amount to decrease the total debt amount by.
     */
    function _decreaseTotalDebt(uint64 amount) internal {
        PayerStorage storage $ = _getPayerStorage();

        $.totalDebt = amount > $.totalDebt ? 0 : $.totalDebt - amount;
    }

    /**
     * @notice Internal helper for paginated access to EnumerableSet.AddressSet.
     * @param  addressSet The EnumerableSet to paginate.
     * @param  offset The starting index.
     * @param  limit Maximum number of items to return.
     * @return addresses Array of addresses from the set.
     * @return hasMore Whether there are more items after this page.
     */
    function _getPaginatedAddresses(
        EnumerableSet.AddressSet storage addressSet,
        uint256 offset,
        uint256 limit
    ) internal view returns (address[] memory addresses, bool hasMore) {
        uint256 totalCount = addressSet.length();

        if (offset >= totalCount) revert OutOfBounds();

        uint256 count = totalCount - offset;
        if (count > limit) {
            count = limit;
            hasMore = true;
        } else {
            hasMore = false;
        }

        addresses = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            addresses[i] = addressSet.at(offset + i);
        }

        return (addresses, hasMore);
    }

    /* ============ Upgradeability ============ */

    /**
     * @dev   Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newImplementation != address(0), InvalidAddress());
        emit UpgradeAuthorized(msg.sender, newImplementation);
    }

    /* ============ ERC165 ============ */

    /**
     * @dev Override to support IPayerRegistry, IERC165 and AccessControlUpgradeable.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(IERC165, AccessControlUpgradeable) returns (bool supported) {
        return interfaceId == type(IPayerRegistry).interfaceId || super.supportsInterface(interfaceId);
    }
}
