// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { EnumerableSet } from "../lib/oz/contracts/utils/structs/EnumerableSet.sol";
import { PausableUpgradeable } from "../lib/oz-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "../lib/oz-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like } from "./interfaces/External.sol";
import { IPayerRegistry } from "./interfaces/IPayerRegistry.sol";

// TODO: `deposit`, `requestWithdrawal`, `cancelWithdrawal`, and `finalizeWithdrawal` with permit.

contract PayerRegistry is IPayerRegistry, Initializable, UUPSUpgradeable, PausableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayerRegistry
    address public immutable token;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.PayerRegistry
    struct PayerRegistryStorage {
        address admin;
        address settler;
        address feeDistributor;
        mapping(address account => Payer payer) payers;
        int104 totalDeposits;
        uint96 totalDebt;
        uint96 minimumDeposit;
        uint32 withdrawLockPeriod;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.PayerRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PAYER_REGISTRY_STORAGE_LOCATION =
        0x98606aa366980dbfce6aa523610c4eabfe62443511d67e10c2c7afde009fbf00;

    function _getPayerRegistryStorage() internal pure returns (PayerRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PAYER_REGISTRY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    modifier onlySettler() {
        _revertIfNotSettler();
        _;
    }

    /* ============ Constructor ============ */

    constructor(address token_) {
        if ((token = token_) == address(0)) revert ZeroTokenAddress();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayerRegistry
    function initialize(
        address admin_,
        address settler_,
        address feeDistributor_,
        uint96 minimumDeposit_,
        uint32 withdrawLockPeriod_
    ) external initializer {
        require(admin_ != address(0), ZeroAdminAddress());

        __UUPSUpgradeable_init();
        __Pausable_init();

        _setAdmin(admin_);
        _setSettler(settler_);
        _setFeeDistributor(feeDistributor_);
        _setMinimumDeposit(minimumDeposit_);
        _setWithdrawLockPeriod(withdrawLockPeriod_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayerRegistry
    function deposit(address payer_, uint96 amount_) external whenNotPaused {
        _deposit(msg.sender, payer_, amount_);
    }

    /// @inheritdoc IPayerRegistry
    function deposit(uint96 amount_) external whenNotPaused {
        _deposit(msg.sender, msg.sender, amount_);
    }

    /// @inheritdoc IPayerRegistry
    function requestWithdrawal(uint96 amount_) external whenNotPaused {
        require(amount_ > 0, ZeroWithdrawalAmount());

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payer_ = $.payers[msg.sender];

        // NOTE: For some reason, slither complains that this is a `Dangerous comparisons: block-timestamp` issue.
        // slither-disable-next-line timestamp
        require(payer_.pendingWithdrawal == 0, PendingWithdrawalExists());

        payer_.pendingWithdrawal = amount_;
        payer_.withdrawableTimestamp = uint32(block.timestamp) + $.withdrawLockPeriod;

        emit WithdrawalRequested(msg.sender, amount_, payer_.withdrawableTimestamp);

        uint96 debtIncurred_ = _decreaseBalance(msg.sender, amount_);

        require(debtIncurred_ == 0, InsufficientBalance());
    }

    /// @inheritdoc IPayerRegistry
    function cancelWithdrawal() external whenNotPaused {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payerInfo_ = $.payers[msg.sender];
        uint96 pendingWithdrawal_ = payerInfo_.pendingWithdrawal;

        require(pendingWithdrawal_ != 0, NoPendingWithdrawal());

        emit WithdrawalCancelled(msg.sender);

        uint96 debtRepaid_ = _increaseBalance(msg.sender, pendingWithdrawal_);

        $.totalDebt -= debtRepaid_;

        delete payerInfo_.pendingWithdrawal;
        delete payerInfo_.withdrawableTimestamp;
    }

    /// @inheritdoc IPayerRegistry
    function finalizeWithdrawal(address recipient_) external whenNotPaused {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payer_ = $.payers[msg.sender];
        uint96 pendingWithdrawal_ = payer_.pendingWithdrawal;

        require(pendingWithdrawal_ > 0, NoPendingWithdrawal());
        require(payer_.balance >= 0, PayerInDebt());

        // slither-disable-next-line timestamp
        require(
            block.timestamp >= payer_.withdrawableTimestamp,
            WithdrawalNotReady(uint32(block.timestamp), payer_.withdrawableTimestamp)
        );

        delete payer_.pendingWithdrawal;
        delete payer_.withdrawableTimestamp;

        $.totalDeposits -= _toInt104(pendingWithdrawal_);

        emit WithdrawalFinalized(msg.sender);

        require(ERC20Helper.transfer(token, recipient_, pendingWithdrawal_), ERC20TransferFailed());
    }

    /// @inheritdoc IPayerRegistry
    function settleUsage(address[] calldata payers_, uint96[] calldata fees_) external onlySettler whenNotPaused {
        require(payers_.length == fees_.length, ArrayLengthMismatch());

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        int104 totalDeposits_ = $.totalDeposits;
        uint96 totalDebt_ = $.totalDebt;

        for (uint256 index_; index_ < payers_.length; ++index_) {
            address payer_ = payers_[index_];
            uint96 fee_ = fees_[index_];

            emit UsageSettled(payer_, fee_);

            totalDeposits_ -= _toInt104(fee_);
            totalDebt_ += _decreaseBalance(payer_, fee_);
        }

        $.totalDeposits = totalDeposits_;
        $.totalDebt = totalDebt_;

        // The excess token in the contract that is not withdrawable by payers can be sent to the fee distributor.
        uint96 totalWithdrawable_ = _getTotalWithdrawable(totalDeposits_, totalDebt_);
        uint96 tokenBalance_ = uint96(IERC20Like(token).balanceOf(address(this)));
        uint96 excess_ = tokenBalance_ > totalWithdrawable_ ? tokenBalance_ - totalWithdrawable_ : 0;

        // slither-disable-next-line incorrect-equality
        if (excess_ == 0) return;

        address feeDistributor_ = $.feeDistributor;

        if (feeDistributor_ == address(0)) return;

        emit FeesTransferred(excess_);

        require(ERC20Helper.transfer(token, feeDistributor_, excess_), ERC20TransferFailed());
    }

    /* ============ Admin functionality ============ */

    /// @inheritdoc IPayerRegistry
    function pause() external onlyAdmin {
        _pause();
    }

    /// @inheritdoc IPayerRegistry
    function unpause() external onlyAdmin {
        _unpause();
    }

    /// @inheritdoc IPayerRegistry
    function setAdmin(address newAdmin_) external onlyAdmin {
        _setAdmin(newAdmin_);
    }

    /// @inheritdoc IPayerRegistry
    function setSettler(address newSettler_) external onlyAdmin {
        _setSettler(newSettler_);
    }

    /// @inheritdoc IPayerRegistry
    function setFeeDistributor(address newFeeDistributor_) external onlyAdmin {
        _setFeeDistributor(newFeeDistributor_);
    }

    /// @inheritdoc IPayerRegistry
    function setMinimumDeposit(uint96 newMinimumDeposit_) external onlyAdmin {
        _setMinimumDeposit(newMinimumDeposit_);
    }

    /// @inheritdoc IPayerRegistry
    function setWithdrawLockPeriod(uint32 newWithdrawLockPeriod_) external onlyAdmin {
        _setWithdrawLockPeriod(newWithdrawLockPeriod_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayerRegistry
    function admin() external view returns (address admin_) {
        return _getPayerRegistryStorage().admin;
    }

    /// @inheritdoc IPayerRegistry
    function settler() external view returns (address settler_) {
        return _getPayerRegistryStorage().settler;
    }

    /// @inheritdoc IPayerRegistry
    function feeDistributor() external view returns (address feeDistributor_) {
        return _getPayerRegistryStorage().feeDistributor;
    }

    /// @inheritdoc IPayerRegistry
    function totalDeposits() public view returns (int104 totalDeposits_) {
        return _getPayerRegistryStorage().totalDeposits;
    }

    /// @inheritdoc IPayerRegistry
    function totalDebt() public view returns (uint96 totalDebt_) {
        return _getPayerRegistryStorage().totalDebt;
    }

    /// @inheritdoc IPayerRegistry
    function totalWithdrawable() external view returns (uint96 totalWithdrawable_) {
        return _getTotalWithdrawable(totalDeposits(), totalDebt());
    }

    /// @inheritdoc IPayerRegistry
    function minimumDeposit() external view returns (uint96 minimumDeposit_) {
        return _getPayerRegistryStorage().minimumDeposit;
    }

    /// @inheritdoc IPayerRegistry
    function withdrawLockPeriod() external view returns (uint32 withdrawLockPeriod_) {
        return _getPayerRegistryStorage().withdrawLockPeriod;
    }

    /// @inheritdoc IPayerRegistry
    function getBalance(address payer_) external view returns (int104 balance_) {
        return _getPayerRegistryStorage().payers[payer_].balance;
    }

    /// @inheritdoc IPayerRegistry
    function getBalances(address[] calldata payers_) external view returns (int104[] memory balances_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        balances_ = new int104[](payers_.length);

        for (uint256 index_; index_ < payers_.length; ++index_) {
            balances_[index_] = $.payers[payers_[index_]].balance;
        }
    }

    /// @inheritdoc IPayerRegistry
    function getPendingWithdrawal(
        address payer_
    ) external view returns (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        return ($.payers[payer_].pendingWithdrawal, $.payers[payer_].withdrawableTimestamp);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev Increases the balance of `payer_` by `amount_`, and returns the debt repaid.
     */
    function _increaseBalance(address payer_, uint96 amount_) internal returns (uint96 debtRepaid_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        int104 startingBalance_ = $.payers[payer_].balance;
        int104 endingBalance_ = ($.payers[payer_].balance = startingBalance_ + _toInt104(amount_));

        return _getDebt(startingBalance_) - _getDebt(endingBalance_);
    }

    /**
     * @dev Decreases the balance of `payer_` by `amount_`, and returns the additional debt incurred.
     */
    function _decreaseBalance(address payer_, uint96 amount_) internal returns (uint96 debtIncurred_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        int104 startingBalance_ = $.payers[payer_].balance;
        int104 endingBalance_ = ($.payers[payer_].balance = startingBalance_ - _toInt104(amount_));

        return _getDebt(endingBalance_) - _getDebt(startingBalance_);
    }

    /**
     * @dev    Returns the debt represented by a balance, if any.
     */
    function _getDebt(int104 balance_) internal pure returns (uint96 debt_) {
        return balance_ < 0 ? uint96(uint104(-balance_)) : 0;
    }

    /**
     * @dev Transfers `amount_` of tokens from `from_` to this contract to satisfy a deposit for `payer_`.
     */
    function _deposit(address from_, address payer_, uint96 amount_) internal {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        require(amount_ >= $.minimumDeposit, InsufficientDeposit(amount_, $.minimumDeposit));

        emit Deposit(payer_, amount_);

        uint96 debtRepaid_ = _increaseBalance(payer_, amount_);

        $.totalDeposits += _toInt104(amount_);
        $.totalDebt -= debtRepaid_;

        require(ERC20Helper.transferFrom(token, from_, address(this), amount_), ERC20TransferFromFailed());
    }

    function _setAdmin(address newAdmin_) internal {
        emit AdminSet(_getPayerRegistryStorage().admin = newAdmin_);
    }

    function _setSettler(address newSettler_) internal {
        require(newSettler_ != address(0), ZeroSettlerAddress());
        emit SettlerSet(_getPayerRegistryStorage().settler = newSettler_);
    }

    function _setFeeDistributor(address newFeeDistributor_) internal {
        require(newFeeDistributor_ != address(0), ZeroFeeDistributorAddress());
        emit FeeDistributorSet(_getPayerRegistryStorage().feeDistributor = newFeeDistributor_);
    }

    function _setMinimumDeposit(uint96 newMinimumDeposit_) internal {
        emit MinimumDepositSet(_getPayerRegistryStorage().minimumDeposit = newMinimumDeposit_);
    }

    function _setWithdrawLockPeriod(uint32 newWithdrawLockPeriod_) internal {
        emit WithdrawLockPeriodSet(_getPayerRegistryStorage().withdrawLockPeriod = newWithdrawLockPeriod_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Returns the sum of all withdrawable balances (sum of all positive payer balances and pending withdrawals).
     */
    function _getTotalWithdrawable(
        int104 totalDeposits_,
        uint96 totalDebt_
    ) internal pure returns (uint96 totalWithdrawable_) {
        // NOTE: `totalDeposits_ + totalDebt_ >= 0` is guaranteed by the contract logic.
        return uint96(uint104(totalDeposits_ + _toInt104(totalDebt_)));
    }

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := input_
        }
    }

    function _revertIfNotAdmin() internal view {
        require(msg.sender == _getPayerRegistryStorage().admin, NotAdmin());
    }

    function _revertIfNotSettler() internal view {
        require(msg.sender == _getPayerRegistryStorage().settler, NotSettler());
    }

    /* ============ Upgradeability ============ */

    /**
     * @dev   Authorizes the upgrade of the contract.
     * @param newImplementation_ The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation_) internal view override onlyAdmin {
        // TODO: Consider reverting if there is no code at the new implementation address.
        require(newImplementation_ != address(0), ZeroImplementationAddress());
    }
}
