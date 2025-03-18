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
    string internal constant USDC_SYMBOL = "USDC";
    uint8 private constant PAYER_OPERATOR_ID = 1;
    uint64 private constant DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint64 private constant DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint64 private constant DEFAULT_MAX_TOLERABLE_DEBT_AMOUNT_MICRO_DOLLARS = 50_000_000;
    uint32 private constant DEFAULT_MINIMUM_TRANSFER_FEES_PERIOD = 6 hours;
    uint32 private constant ABSOLUTE_MINIMUM_TRANSFER_FEES_PERIOD = 1 hours;
    uint32 private constant DEFAULT_WITHDRAWAL_LOCK_PERIOD = 3 days;
    uint32 private constant ABSOLUTE_MINIMUM_WITHDRAWAL_LOCK_PERIOD = 1 days;

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
    bytes32 internal constant PAYER_STORAGE_LOCATION =
        0xd0335f337c570f3417b0f0d20340c88da711d60e810b5e9b3ecabe9ccfcdce5a;

    function _getPayerStorage() internal pure returns (PayerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := PAYER_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    /**
     * @dev Modifier to check if caller is an active node operator.
     */
    modifier onlyNodeOperator(uint256 nodeId) {
        require(_getIsActiveNodeOperator(nodeId), UnauthorizedNodeOperator());
        _;
    }

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

        $.minimumRegistrationAmountMicroDollars = DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS;
        $.minimumDepositAmountMicroDollars = DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS;
        $.withdrawalLockPeriod = DEFAULT_WITHDRAWAL_LOCK_PERIOD;
        $.maxTolerableDebtAmountMicroDollars = DEFAULT_MAX_TOLERABLE_DEBT_AMOUNT_MICRO_DOLLARS;
        $.transferFeesPeriod = DEFAULT_MINIMUM_TRANSFER_FEES_PERIOD;

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
    function deactivatePayer(uint256 nodeId, address payer) external whenNotPaused onlyNodeOperator(nodeId) {
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

        Payer memory _storedPayer = $.payers[payer];

        if (_storedPayer.balance > 0 || _storedPayer.debtAmount > 0) {
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

        Payer memory _storedPayer = $.payers[msg.sender];

        require(_storedPayer.debtAmount == 0, PayerHasDebt());
        require(_storedPayer.balance >= amount, InsufficientBalance());

        // Balance to be withdrawn is deducted from the payer's balance,
        // it can't be used to settle payments.
        $.payers[msg.sender].balance -= amount;
        _decreaseTotalDeposited(amount);

        uint64 withdrawableTimestamp = uint64(block.timestamp) + $.withdrawalLockPeriod;

        $.withdrawals[msg.sender] = Withdrawal({
            withdrawableTimestamp: withdrawableTimestamp,
            amount: amount
        });

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalRequested(msg.sender, withdrawableTimestamp, amount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function cancelWithdrawal() external whenNotPaused onlyPayer(msg.sender) {
        _revertIfWithdrawalNotExists(msg.sender);

        PayerStorage storage $ = _getPayerStorage();

        Withdrawal memory _withdrawal = $.withdrawals[msg.sender];

        delete $.withdrawals[msg.sender];

        $.payers[msg.sender].balance += _withdrawal.amount;
        _increaseTotalDeposited(_withdrawal.amount);

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalCancelled(msg.sender, _withdrawal.withdrawableTimestamp);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function finalizeWithdrawal() external whenNotPaused nonReentrant onlyPayer(msg.sender) {
        _revertIfWithdrawalNotExists(msg.sender);

        PayerStorage storage $ = _getPayerStorage();

        Withdrawal memory _withdrawal = $.withdrawals[msg.sender];

        require(block.timestamp >= _withdrawal.withdrawableTimestamp, WithdrawalPeriodNotElapsed());

        delete $.withdrawals[msg.sender];

        uint64 _finalWithdrawalAmount = _withdrawal.amount;

        if ($.payers[msg.sender].debtAmount > 0) {
            _finalWithdrawalAmount = _settleDebts(msg.sender, _withdrawal.amount, true);
        }

        if (_finalWithdrawalAmount > 0) {
            IERC20($.usdcToken).safeTransfer(msg.sender, _finalWithdrawalAmount);
        }

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance, $.payers[msg.sender].debtAmount);

        emit WithdrawalFinalized(msg.sender, _withdrawal.withdrawableTimestamp, _finalWithdrawalAmount);
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
    function settleUsage(uint256 originatorNode, address[] calldata payerList, uint64[] calldata usageAmountsList)
        external
        whenNotPaused
        nonReentrant
        onlyPayerReport
    {
        require(payerList.length == usageAmountsList.length, InvalidPayerListLength());

        PayerStorage storage $ = _getPayerStorage();

        uint64 _settledFees = 0;
        uint64 _pendingFees = $.pendingFees;

        for (uint256 i = 0; i < payerList.length; i++) {
            address payer = payerList[i];
            uint64 usage = usageAmountsList[i];

            // This should never happen, as PayerReport has already verified the payers and amounts.
            // Payers in payerList should always exist and be active.
            if (!_payerExists(payer) || !_payerIsActive(payer)) continue;

            Payer memory _storedPayer = $.payers[payer];

            if (_storedPayer.balance < usage) {
                uint64 _debt = usage - _storedPayer.balance;

                _settledFees += _storedPayer.balance;
                _pendingFees += _storedPayer.balance;

                _storedPayer.balance = 0;
                _storedPayer.debtAmount = _debt;
                $.payers[payer] = _storedPayer;

                _addDebtor(payer);
                _increaseTotalDebt(_debt);

                if (_debt > $.maxTolerableDebtAmountMicroDollars) _deactivatePayer(PAYER_OPERATOR_ID, payer);

                emit PayerBalanceUpdated(payer, _storedPayer.balance, _storedPayer.debtAmount);

                continue;
            }

            _settledFees += usage;
            _pendingFees += usage;

            _storedPayer.balance -= usage;

            $.payers[payer] = _storedPayer;

            emit PayerBalanceUpdated(payer, _storedPayer.balance, _storedPayer.debtAmount);
        }

        $.pendingFees = _pendingFees;

        emit UsageSettled(originatorNode, uint64(block.timestamp), _settledFees);
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

        uint64 _pendingFeesAmount = $.pendingFees;

        require(_pendingFeesAmount > 0, InsufficientAmount());

        IERC20($.usdcToken).safeTransfer($.feeDistributor, _pendingFeesAmount);

        $.lastFeeTransferTimestamp = uint64(block.timestamp);
        $.collectedFees += _pendingFeesAmount;
        $.pendingFees = 0;

        emit FeesTransferred(uint64(block.timestamp), _pendingFeesAmount);
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
        require(newMinimumDeposit > DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS, InvalidMinimumDeposit());

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
            newMinimumRegistrationAmount > DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS,
            InvalidMinimumRegistrationAmount()
        );

        PayerStorage storage $ = _getPayerStorage();

        uint64 _oldMinimumRegistrationAmount = $.minimumRegistrationAmountMicroDollars;
        $.minimumRegistrationAmountMicroDollars = newMinimumRegistrationAmount;

        emit MinimumRegistrationAmountSet(_oldMinimumRegistrationAmount, newMinimumRegistrationAmount);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setWithdrawalLockPeriod(uint32 newWithdrawalLockPeriod) external onlyRole(ADMIN_ROLE) {
        require(newWithdrawalLockPeriod >= ABSOLUTE_MINIMUM_WITHDRAWAL_LOCK_PERIOD, InvalidWithdrawalLockPeriod());

        PayerStorage storage $ = _getPayerStorage();

        uint32 _oldWithdrawalLockPeriod = $.withdrawalLockPeriod;
        $.withdrawalLockPeriod = newWithdrawalLockPeriod;

        emit WithdrawalLockPeriodSet(_oldWithdrawalLockPeriod, newWithdrawalLockPeriod);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setMaxTolerableDebtAmount(uint64 newMaxTolerableDebtAmountMicroDollars) external onlyRole(ADMIN_ROLE) {
        require(newMaxTolerableDebtAmountMicroDollars > 0, InvalidMaxTolerableDebtAmount());

        PayerStorage storage $ = _getPayerStorage();

        uint64 _oldMaxTolerableDebtAmount = $.maxTolerableDebtAmountMicroDollars;
        $.maxTolerableDebtAmountMicroDollars = newMaxTolerableDebtAmountMicroDollars;

        emit MaxTolerableDebtAmountSet(_oldMaxTolerableDebtAmount, newMaxTolerableDebtAmountMicroDollars);
    }

    /**
     * @inheritdoc IPayerRegistry
     */
    function setTransferFeesPeriod(uint32 newTransferFeesPeriod) external onlyRole(ADMIN_ROLE) {
        require(newTransferFeesPeriod >= ABSOLUTE_MINIMUM_TRANSFER_FEES_PERIOD, InvalidTransferFeesPeriod());

        PayerStorage storage $ = _getPayerStorage();

        uint32 _oldTransferFeesPeriod = $.transferFeesPeriod;
        $.transferFeesPeriod = newTransferFeesPeriod;

        emit TransferFeesPeriodSet(_oldTransferFeesPeriod, newTransferFeesPeriod);
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
    function getActivePayers(uint32 offset, uint32 limit)
        external
        view
        returns (Payer[] memory payers, bool hasMore)
    {
        PayerStorage storage $ = _getPayerStorage();

        (address[] memory _payerAddresses, bool _hasMore) = _getPaginatedAddresses($.activePayers, offset, limit);

        payers = new Payer[](_payerAddresses.length);
        for (uint256 i = 0; i < _payerAddresses.length; i++) {
            payers[i] = $.payers[_payerAddresses[i]];
        }

        return (payers, _hasMore);
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
    function getPayersInDebt(uint32 offset, uint32 limit)
        external
        view
        returns (Payer[] memory payers, bool hasMore)
    {
        PayerStorage storage $ = _getPayerStorage();

        (address[] memory _payerAddresses, bool _hasMore) = _getPaginatedAddresses($.debtPayers, offset, limit);

        payers = new Payer[](_payerAddresses.length);
        for (uint256 i = 0; i < _payerAddresses.length; i++) {
            payers[i] = $.payers[_payerAddresses[i]];
        }

        return (payers, _hasMore);
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
        Payer storage _payer = _getPayerStorage().payers[payerAddress];

        if (_payer.debtAmount > 0) {
            return _settleDebts(payerAddress, amount, false);
        } else {
            _payer.balance += amount;
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
    function _settleDebts(address payer, uint64 amount, bool isWithdrawal) internal returns (uint64 amountAfterSettlement) {
        PayerStorage storage $ = _getPayerStorage();

        Payer memory _storedPayer = $.payers[payer];

        if (_storedPayer.debtAmount < amount) {
            uint64 _debtToRemove = _storedPayer.debtAmount;
            amount -= _debtToRemove;

            // For regular deposits, add remaining amount to balance.
            // In withdrawals, that amount was moved to the withdrawal balance.
            if (!isWithdrawal) {
                _storedPayer.balance += amount;
                _increaseTotalDeposited(amount);
            }

            _removeDebtor(payer);
            _increaseTotalDeposited(amount);
            _decreaseTotalDebt(_debtToRemove);

            amountAfterSettlement = amount;
        } else {
            _storedPayer.debtAmount -= amount;

            _decreaseTotalDebt(amount);

            amountAfterSettlement = 0;
        }

        $.payers[payer] = _storedPayer;

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
     * @notice Checks if a given address is an active node operator.
     * @param  nodeId The nodeID of the operator to check.
     * @return isActiveNodeOperator True if the address is an active node operator, false otherwise.
     */
    function _getIsActiveNodeOperator(uint256 nodeId) internal view returns (bool isActiveNodeOperator) {
        INodes nodes = INodes(_getPayerStorage().nodeRegistry);

        require(msg.sender == nodes.ownerOf(nodeId), Unauthorized());

        // TODO: Change for a better filter.
        return nodes.getReplicationNodeIsActive(nodeId);
    }

    /**
     * @notice Sets the FeeDistributor contract.
     * @param  newFeeDistributor The address of the new FeeDistributor contract.
     */
    function _setFeeDistributor(address newFeeDistributor) internal {
        PayerStorage storage $ = _getPayerStorage();

        try IFeeDistributor(newFeeDistributor).supportsInterface(type(IFeeDistributor).interfaceId) returns (bool supported) {
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

        try IPayerReportManager(newPayerReportManager).supportsInterface(type(IPayerReportManager).interfaceId) returns (bool supported) {
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
            require(keccak256(bytes(symbol)) == keccak256(bytes(USDC_SYMBOL)), InvalidUsdcTokenContract());
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
    function _getPaginatedAddresses(EnumerableSet.AddressSet storage addressSet, uint256 offset, uint256 limit)
        internal
        view
        returns (address[] memory addresses, bool hasMore)
    {
        uint256 _totalCount = addressSet.length();

        if (offset >= _totalCount) revert OutOfBounds();

        uint256 _count = _totalCount - offset;
        if (_count > limit) {
            _count = limit;
            hasMore = true;
        } else {
            hasMore = false;
        }

        addresses = new address[](_count);

        for (uint256 i = 0; i < _count; i++) {
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
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, AccessControlUpgradeable)
        returns (bool supported)
    {
        return interfaceId == type(IPayerRegistry).interfaceId || super.supportsInterface(interfaceId);
    }
}
