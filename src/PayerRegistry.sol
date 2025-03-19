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
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";
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
    uint64 private constant _DEFAULT_MINIMUM_REGISTRATION_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint64 private constant _DEFAULT_MINIMUM_DEPOSIT_AMOUNT_MICRO_DOLLARS = 10_000_000;
    uint32 private constant _DEFAULT_MINIMUM_TRANSFER_FEES_PERIOD = 6 hours;
    uint32 private constant _ABSOLUTE_MINIMUM_TRANSFER_FEES_PERIOD = 1 hours;
    uint32 private constant _DEFAULT_WITHDRAWAL_LOCK_PERIOD = 3 days;
    uint32 private constant _ABSOLUTE_MINIMUM_WITHDRAWAL_LOCK_PERIOD = 1 days;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.Payer
    struct PayerStorage {
        uint64 minimumRegistrationAmountMicroDollars;
        uint64 minimumDepositAmountMicroDollars;
        uint64 pendingFees;
        uint64 collectedFees;
        uint64 lastFeeTransferTimestamp;
        uint32 withdrawalLockPeriod;
        uint32 transferFeesPeriod;
        address usdcToken;
        address feeDistributor;
        address nodeRegistry;
        address payerReportManager;
        mapping(address => Payer) payers;
        mapping(address => Withdrawal) withdrawals;
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
        $.payers[msg.sender] = Payer({ balance: int64(amount), latestDepositTimestamp: uint64(block.timestamp) });

        // Add new payer to active and total payers sets
        require($.activePayers.add(msg.sender), FailedToRegisterPayer());

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

    /* ========== Payers Balance Management ========= */

    /**
     * @inheritdoc IPayerRegistry
     */
    function requestWithdrawal(uint64 amount) external whenNotPaused onlyPayer(msg.sender) {
        if (_withdrawalExists(msg.sender)) revert WithdrawalAlreadyRequested();

        PayerStorage storage $ = _getPayerStorage();

        require($.payers[msg.sender].balance >= int64(amount), InsufficientBalance());

        // Balance to be withdrawn is deducted from the payer's balance,
        // it can't be used to settle payments.
        $.payers[msg.sender].balance -= int64(amount);

        uint64 withdrawableTimestamp = uint64(block.timestamp) + $.withdrawalLockPeriod;

        $.withdrawals[msg.sender] = Withdrawal({ withdrawableTimestamp: withdrawableTimestamp, amount: amount });

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance);

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

        $.payers[msg.sender].balance += int64(withdrawal.amount);

        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance);

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

        if ($.payers[msg.sender].balance < 0) {
            finalWithdrawalAmount = _settleDebtsBeforeWithdrawal(msg.sender, withdrawal.amount);
        }

        if (finalWithdrawalAmount > 0) {
            IERC20($.usdcToken).safeTransfer(msg.sender, finalWithdrawalAmount);
        }

        /// @dev re-emitting the balance update, as it can change due to debt settlement.
        emit PayerBalanceUpdated(msg.sender, $.payers[msg.sender].balance);

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
            // In case it does, skip the payer and process the rest.
            if (!_payerExists(payer)) continue;

            Payer memory storedPayer = $.payers[payer];

            if (storedPayer.balance >= int64(usage)) {
                settledFees += usage;
                pendingFees += usage;

                storedPayer.balance -= int64(usage);

                $.payers[payer] = storedPayer;

                emit PayerBalanceUpdated(payer, storedPayer.balance);

                continue;
            }

            if (storedPayer.balance < 0) {
                storedPayer.balance -= int64(usage);

                $.payers[payer] = storedPayer;

                emit PayerBalanceUpdated(payer, storedPayer.balance);

                continue;
            }

            // Payer has balance, but not enough to settle the usage.
            _addDebtor(payer);

            settledFees += uint64(storedPayer.balance);
            pendingFees += uint64(storedPayer.balance);

            storedPayer.balance -= int64(usage);

            $.payers[payer] = storedPayer;

            emit PayerBalanceUpdated(payer, storedPayer.balance);
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
     * @inheritdoc IPayerRegistry
     */
    function setPayerReportManager(address newPayerReportManager) external onlyRole(ADMIN_ROLE) {
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
    function getPayerBalance(address payer) external view returns (int64 balance) {
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
    function getLastFeeTransferTimestamp() external view returns (uint64 timestamp) {
        return _getPayerStorage().lastFeeTransferTimestamp;
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

        $.payers[to].balance += int64(amount);

        emit PayerBalanceUpdated(to, $.payers[to].balance);
    }

    /**
     * @notice Settles debts for a payer before withdrawal.
     * @param  payer The address of the payer.
     * @param  amount The withdrawal amount that can be used to settle debt.
     * @return remainingAmount The amount left for withdrawal after settling debt.
     */
    function _settleDebtsBeforeWithdrawal(address payer, uint64 amount) internal returns (uint64 remainingAmount) {
        Payer storage payerData = _getPayerStorage().payers[payer];

        if (payerData.balance >= 0) return amount;

        // Balance is always negative, we can safely negate it to get the debt.
        uint64 debt = uint64(-payerData.balance);

        // If debt is greater than or equal to the withdrawal amount,
        // use the entire amount to reduce debt.
        if (debt >= amount) {
            payerData.balance += int64(amount);

            // If balance is now 0, remove from debtors
            if (payerData.balance == 0) _removeDebtor(payer);

            return 0;
        }

        payerData.balance = 0;

        _removeDebtor(payer);

        // Return remaining amount after settling debt
        return amount - debt;
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
     * @notice Sets the NodeRegistry contract.
     * @param  newNodeRegistry The address of the new NodeRegistry contract.
     */
    function _setNodeRegistry(address newNodeRegistry) internal {
        PayerStorage storage $ = _getPayerStorage();

        try INodeRegistry(newNodeRegistry).supportsInterface(type(INodeRegistry).interfaceId) returns (bool supported) {
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
