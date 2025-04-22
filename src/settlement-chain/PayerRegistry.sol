// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20Helper } from "../../lib/erc20-helper/src/ERC20Helper.sol";
import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC20Like } from "./interfaces/External.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IPayerRegistry } from "./interfaces/IPayerRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: `deposit`, `requestWithdrawal`, `cancelWithdrawal`, and `finalizeWithdrawal` with permit.

contract PayerRegistry is IPayerRegistry, Migratable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayerRegistry
    address public immutable parameterRegistry;

    /// @inheritdoc IPayerRegistry
    address public immutable token;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.PayerRegistry
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
     * @notice Constructor for the PayerRegistry contract.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @param  token_             The address of the token.
     */
    constructor(address parameterRegistry_, address token_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
        require(_isNotZero(token = token_), ZeroTokenAddress());
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayerRegistry
    function initialize() external initializer {
        _updateSettler();
        _updateFeeDistributor();
        _updateMinimumDeposit();
        _updateWithdrawLockPeriod();
        _updatePauseStatus();
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

    /// @inheritdoc IPayerRegistry
    function updateSettler() external {
        require(_updateSettler(), NoChange());
    }

    /// @inheritdoc IPayerRegistry
    function updateFeeDistributor() external {
        require(_updateFeeDistributor(), NoChange());
    }

    /// @inheritdoc IPayerRegistry
    function updateMinimumDeposit() external {
        require(_updateMinimumDeposit(), NoChange());
    }

    /// @inheritdoc IPayerRegistry
    function updateWithdrawLockPeriod() external {
        require(_updateWithdrawLockPeriod(), NoChange());
    }

    /// @inheritdoc IPayerRegistry
    function updatePauseStatus() external {
        require(_updatePauseStatus(), NoChange());
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

    function _updateSettler() internal returns (bool changed_) {
        address newSettler_ = _toAddress(_getRegistryParameter(settlerParameterKey()));
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        require(_isNotZero(newSettler_), ZeroSettlerAddress());

        changed_ = newSettler_ != $.settler;

        emit SettlerUpdated($.settler = newSettler_);
    }

    function _updateFeeDistributor() internal returns (bool changed_) {
        address newFeeDistributor_ = _toAddress(_getRegistryParameter(feeDistributorParameterKey()));
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        require(_isNotZero(newFeeDistributor_), ZeroFeeDistributorAddress());

        changed_ = newFeeDistributor_ != $.feeDistributor;

        emit FeeDistributorUpdated($.feeDistributor = newFeeDistributor_);
    }

    function _updateMinimumDeposit() internal returns (bool changed_) {
        uint96 newMinimumDeposit_ = _toUint96(_getRegistryParameter(minimumDepositParameterKey()));
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        require(newMinimumDeposit_ != 0, ZeroMinimumDeposit());

        changed_ = newMinimumDeposit_ != $.minimumDeposit;

        emit MinimumDepositUpdated($.minimumDeposit = newMinimumDeposit_);
    }

    function _updateWithdrawLockPeriod() internal returns (bool changed_) {
        uint32 newWithdrawLockPeriod_ = _toUint32(_getRegistryParameter(withdrawLockPeriodParameterKey()));
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        changed_ = newWithdrawLockPeriod_ != $.withdrawLockPeriod;

        emit WithdrawLockPeriodUpdated($.withdrawLockPeriod = newWithdrawLockPeriod_);
    }

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

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
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
        require(msg.sender == _getPayerRegistryStorage().settler, NotSettler());
    }

    function _revertIfPaused() internal view {
        require(!_getPayerRegistryStorage().paused, Paused());
    }
}
