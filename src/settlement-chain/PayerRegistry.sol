// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC20Like, IParameterRegistryLike } from "./interfaces/External.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IPayerRegistry } from "./interfaces/IPayerRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: `depositWithPermit`.

/**
 * @title  Implementation of the Payer Registry.
 * @notice This contract is responsible for:
 *           - handling deposits, withdrawals, and usage settlements for payers,
 *           - settling usage fees for payers,
 *           - sending excess tokens to the fee distributor.
 */
contract PayerRegistry is IPayerRegistry, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayerRegistry
    address public immutable parameterRegistry;

    /// @inheritdoc IPayerRegistry
    address public immutable token;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.PayerRegistry
     * @notice The UUPS storage for the payer registry.
     * @param  paused             The pause status.
     * @param  totalDeposits      The sum of all payer balances and pending withdrawals.
     * @param  totalDebt          The sum of all payer debts.
     * @param  withdrawLockPeriod The withdraw lock period.
     * @param  minimumDeposit     The minimum deposit.
     * @param  settler            The address of the settler.
     * @param  feeDistributor     The address of the fee distributor.
     * @param  payers             A mapping of payer addresses to payer information.
     */
    struct PayerRegistryStorage {
        bool paused;
        int104 totalDeposits;
        uint96 totalDebt;
        uint32 withdrawLockPeriod;
        uint96 minimumDeposit;
        address settler;
        address feeDistributor;
        mapping(address account => Payer payer) payers;
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

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
    }

    modifier onlySettler() {
        _revertIfNotSettler();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @param  token_             The address of the token.
     * @dev    The parameter registry and token must not be the zero address.
     * @dev    The parameter registry and token are immutable so that they are inlined in the contract code, and have
     *         minimal gas cost.
     */
    constructor(address parameterRegistry_, address token_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(token = token_)) revert ZeroToken();
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayerRegistry
    function initialize() external initializer {
        _updateSettler();
        _updateFeeDistributor();
        _updateMinimumDeposit();
        _updateWithdrawLockPeriod();
        _updatePauseStatus(); // The contract may start out paused, as needed.
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
        if (amount_ == 0) revert ZeroWithdrawalAmount();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payer_ = $.payers[msg.sender];

        // NOTE: For some reason, slither complains that this is a `Dangerous comparisons: block-timestamp` issue.
        // slither-disable-next-line timestamp
        if (payer_.pendingWithdrawal != 0) revert PendingWithdrawalExists();

        payer_.pendingWithdrawal = amount_;
        payer_.withdrawableTimestamp = uint32(block.timestamp) + $.withdrawLockPeriod;

        emit WithdrawalRequested(msg.sender, amount_, payer_.withdrawableTimestamp);

        uint96 debtIncurred_ = _decreaseBalance(msg.sender, amount_);

        // If debt was incurred decreasing the payer's balance, then the payer's balance must have been insufficient.
        if (debtIncurred_ != 0) revert InsufficientBalance();
    }

    /// @inheritdoc IPayerRegistry
    function cancelWithdrawal() external whenNotPaused {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payerInfo_ = $.payers[msg.sender];
        uint96 pendingWithdrawal_ = payerInfo_.pendingWithdrawal;

        if (pendingWithdrawal_ == 0) revert NoPendingWithdrawal();

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

        if (pendingWithdrawal_ == 0) revert NoPendingWithdrawal();
        if (payer_.balance < 0) revert PayerInDebt();

        // slither-disable-next-line timestamp
        if (block.timestamp < payer_.withdrawableTimestamp) {
            revert WithdrawalNotReady(uint32(block.timestamp), payer_.withdrawableTimestamp);
        }

        delete payer_.pendingWithdrawal;
        delete payer_.withdrawableTimestamp;

        $.totalDeposits -= _toInt104(pendingWithdrawal_);

        emit WithdrawalFinalized(msg.sender);

        SafeTransferLib.safeTransfer(token, recipient_, pendingWithdrawal_);
    }

    /// @inheritdoc IPayerRegistry
    function settleUsage(
        PayerFee[] calldata payerFees_
    ) external onlySettler whenNotPaused returns (uint96 feesSettled_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        int104 totalDeposits_ = $.totalDeposits;
        uint96 totalDebt_ = $.totalDebt;

        for (uint256 index_; index_ < payerFees_.length; ++index_) {
            address payer_ = payerFees_[index_].payer;
            uint96 fee_ = payerFees_[index_].fee;

            emit UsageSettled(payer_, fee_);

            feesSettled_ += fee_;
            totalDeposits_ -= _toInt104(fee_);
            totalDebt_ += _decreaseBalance(payer_, fee_);
        }

        $.totalDeposits = totalDeposits_;
        $.totalDebt = totalDebt_;
    }

    /// @inheritdoc IPayerRegistry
    function sendExcessToFeeDistributor() external whenNotPaused returns (uint96 excess_) {
        // slither-disable-next-line incorrect-equality
        if ((excess_ = excess()) == 0) revert NoExcess();

        address feeDistributor_ = _getPayerRegistryStorage().feeDistributor;

        if (_isZero(feeDistributor_)) revert ZeroFeeDistributor();

        emit ExcessTransferred(excess_);

        SafeTransferLib.safeTransfer(token, feeDistributor_, excess_);
    }

    /// @inheritdoc IPayerRegistry
    function updateSettler() external {
        if (!_updateSettler()) revert NoChange();
    }

    /// @inheritdoc IPayerRegistry
    function updateFeeDistributor() external {
        if (!_updateFeeDistributor()) revert NoChange();
    }

    /// @inheritdoc IPayerRegistry
    function updateMinimumDeposit() external {
        if (!_updateMinimumDeposit()) revert NoChange();
    }

    /// @inheritdoc IPayerRegistry
    function updateWithdrawLockPeriod() external {
        if (!_updateWithdrawLockPeriod()) revert NoChange();
    }

    /// @inheritdoc IPayerRegistry
    function updatePauseStatus() external {
        if (!_updatePauseStatus()) revert NoChange();
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayerRegistry
    function settlerParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.settler";
    }

    /// @inheritdoc IPayerRegistry
    function feeDistributorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.feeDistributor";
    }

    /// @inheritdoc IPayerRegistry
    function minimumDepositParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.minimumDeposit";
    }

    /// @inheritdoc IPayerRegistry
    function withdrawLockPeriodParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.withdrawLockPeriod";
    }

    /// @inheritdoc IPayerRegistry
    function pausedParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.paused";
    }

    /// @inheritdoc IPayerRegistry
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.payerRegistry.migrator";
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
    function paused() external view returns (bool paused_) {
        return _getPayerRegistryStorage().paused;
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
    function excess() public view returns (uint96 excess_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        uint96 totalWithdrawable_ = _getTotalWithdrawable($.totalDeposits, $.totalDebt);
        uint96 tokenBalance_ = uint96(IERC20Like(token).balanceOf(address(this)));

        return tokenBalance_ > totalWithdrawable_ ? tokenBalance_ - totalWithdrawable_ : 0;
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
     * @dev Returns the debt represented by a balance, if any.
     */
    function _getDebt(int104 balance_) internal pure returns (uint96 debt_) {
        return balance_ < 0 ? uint96(uint104(-balance_)) : 0;
    }

    /**
     * @dev Transfers `amount_` of tokens from `from_` to this contract to satisfy a deposit for `payer_`.
     */
    function _deposit(address from_, address payer_, uint96 amount_) internal {
        if (amount_ < _getPayerRegistryStorage().minimumDeposit) {
            revert InsufficientDeposit(amount_, _getPayerRegistryStorage().minimumDeposit);
        }

        SafeTransferLib.safeTransferFrom(token, from_, address(this), amount_);

        uint96 debtRepaid_ = _increaseBalance(payer_, amount_);

        _getPayerRegistryStorage().totalDebt -= debtRepaid_;
        _getPayerRegistryStorage().totalDeposits += _toInt104(amount_);

        // slither-disable-next-line reentrancy-events
        emit Deposit(payer_, amount_);
    }

    /// @dev Sets the settler address by fetching it from the parameter registry, returning whether it changed.
    function _updateSettler() internal returns (bool changed_) {
        address newSettler_ = _toAddress(_getRegistryParameter(settlerParameterKey()));

        if (_isZero(newSettler_)) revert ZeroSettler();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.settler == newSettler_) return false;

        $.settler = newSettler_;

        emit SettlerUpdated(newSettler_);

        return true;
    }

    /// @dev Sets the fee distributor address by fetching it from the parameter registry, returning whether it changed.
    function _updateFeeDistributor() internal returns (bool changed_) {
        address newFeeDistributor_ = _toAddress(_getRegistryParameter(feeDistributorParameterKey()));

        if (_isZero(newFeeDistributor_)) revert ZeroFeeDistributor();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.feeDistributor == newFeeDistributor_) return false;

        $.feeDistributor = newFeeDistributor_;

        emit FeeDistributorUpdated(newFeeDistributor_);

        return true;
    }

    /// @dev Sets the minimum deposit by fetching it from the parameter registry, returning whether it changed.
    function _updateMinimumDeposit() internal returns (bool changed_) {
        uint96 newMinimumDeposit_ = _toUint96(_getRegistryParameter(minimumDepositParameterKey()));

        if (newMinimumDeposit_ == 0) revert ZeroMinimumDeposit();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.minimumDeposit == newMinimumDeposit_) return false;

        $.minimumDeposit = newMinimumDeposit_;

        emit MinimumDepositUpdated(newMinimumDeposit_);

        return true;
    }

    /// @dev Sets the withdraw lock period by fetching it from the parameter registry, returning whether it changed.
    function _updateWithdrawLockPeriod() internal returns (bool changed_) {
        uint32 newWithdrawLockPeriod_ = _toUint32(_getRegistryParameter(withdrawLockPeriodParameterKey()));
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        changed_ = newWithdrawLockPeriod_ != $.withdrawLockPeriod;

        emit WithdrawLockPeriodUpdated($.withdrawLockPeriod = newWithdrawLockPeriod_);
    }

    /// @dev Sets the pause status by fetching it from the parameter registry, returning whether it changed.
    function _updatePauseStatus() internal returns (bool changed_) {
        bool paused_ = _getRegistryParameter(pausedParameterKey()) != bytes32(0);
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        changed_ = paused_ != $.paused;

        emit PauseStatusUpdated($.paused = paused_);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

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

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := input_
        }
    }

    function _toUint32(bytes32 value_) internal pure returns (uint32 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := value_
        }
    }

    function _toUint96(bytes32 value_) internal pure returns (uint96 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := value_
        }
    }

    function _revertIfNotSettler() internal view {
        if (msg.sender != _getPayerRegistryStorage().settler) revert NotSettler();
    }

    function _revertIfPaused() internal view {
        if (_getPayerRegistryStorage().paused) revert Paused();
    }
}
