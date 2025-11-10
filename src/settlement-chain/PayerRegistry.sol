// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IERC20Like, IFeeTokenLike, IPermitErc20Like } from "./interfaces/External.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IPayerRegistry } from "./interfaces/IPayerRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Payer Registry.
 * @notice This contract is responsible for:
 *           - handling deposits, withdrawals, and usage settlements for payers,
 *           - settling usage fees for payers,
 *           - sending excess fee tokens to the fee distributor.
 */
contract PayerRegistry is IPayerRegistry, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayerRegistry
    address public immutable parameterRegistry;

    /// @inheritdoc IPayerRegistry
    address public immutable feeToken;

    /// @dev The address of the token underlying the fee token.
    address internal immutable _underlyingFeeToken;

    /// @dev The maximum withdraw lock period that can be configured.
    uint32 internal constant _MAX_WITHDRAW_LOCK_PERIOD = 30 days;

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
     * @param  feeToken_          The address of the fee token.
     * @dev    The parameter registry and fee token must not be the zero address.
     * @dev    The parameter registry and fee token are immutable so that they are inlined in the contract code, and
     *         have minimal gas cost.
     */
    constructor(address parameterRegistry_, address feeToken_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(feeToken = feeToken_)) revert ZeroFeeToken();

        _underlyingFeeToken = IFeeTokenLike(feeToken).underlying();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayerRegistry
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayerRegistry
    function deposit(address payer_, uint96 amount_) external {
        _depositFeeToken(payer_, amount_);
    }

    /// @inheritdoc IPayerRegistry
    function depositWithPermit(
        address payer_,
        uint96 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither the permit use nor `_depositFeeToken` can result in a reentrancy.
        _usePermit(feeToken, amount_, deadline_, v_, r_, s_);
        _depositFeeToken(payer_, amount_);
    }

    /// @inheritdoc IPayerRegistry
    function depositFromUnderlying(address payer_, uint96 amount_) external {
        _depositFromUnderlying(payer_, amount_);
    }

    /// @inheritdoc IPayerRegistry
    function depositFromUnderlyingWithPermit(
        address payer_,
        uint96 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        // NOTE: There is no issue if the underlying fee token permit use results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy. Further, the permit must be used before being
        //       able to pull any underlying fee tokens from the caller.
        _usePermit(_underlyingFeeToken, amount_, deadline_, v_, r_, s_);
        _depositFromUnderlying(payer_, amount_);
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
        payer_.withdrawalNonce = uint24(payer_.withdrawalNonce + 1);

        emit WithdrawalRequested(msg.sender, amount_, payer_.withdrawableTimestamp, payer_.withdrawalNonce);

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

        emit WithdrawalCancelled(msg.sender, payerInfo_.withdrawalNonce);

        uint96 debtRepaid_ = _increaseBalance(msg.sender, pendingWithdrawal_);

        $.totalDebt -= debtRepaid_;

        delete payerInfo_.pendingWithdrawal;
        delete payerInfo_.withdrawableTimestamp;
    }

    /// @inheritdoc IPayerRegistry
    function finalizeWithdrawal(address recipient_) external {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transfer(recipient_, _finalizeWithdrawal(recipient_));
    }

    /// @inheritdoc IPayerRegistry
    function finalizeWithdrawalIntoUnderlying(address recipient_) external {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unused-return
        IFeeTokenLike(feeToken).withdrawTo(recipient_, _finalizeWithdrawal(recipient_));
    }

    /// @inheritdoc IPayerRegistry
    function settleUsage(
        bytes32 payerReportId_,
        PayerFee[] calldata payerFees_
    ) external onlySettler whenNotPaused returns (uint96 feesSettled_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        int104 totalDeposits_ = $.totalDeposits;
        uint96 totalDebt_ = $.totalDebt;

        for (uint256 index_; index_ < payerFees_.length; ++index_) {
            address payer_ = payerFees_[index_].payer;
            uint96 fee_ = payerFees_[index_].fee;

            emit UsageSettled(payerReportId_, payer_, fee_);

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

        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transfer(feeDistributor_, excess_);
    }

    /// @inheritdoc IPayerRegistry
    function updateSettler() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        address settler_ = RegistryParameters.getAddressParameter(parameterRegistry, settlerParameterKey());

        if (_isZero(settler_)) revert ZeroSettler();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.settler == settler_) revert NoChange();

        emit SettlerUpdated($.settler = settler_);
    }

    /// @inheritdoc IPayerRegistry
    function updateFeeDistributor() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        address feeDistributor_ = RegistryParameters.getAddressParameter(
            parameterRegistry,
            feeDistributorParameterKey()
        );

        if (_isZero(feeDistributor_)) revert ZeroFeeDistributor();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.feeDistributor == feeDistributor_) revert NoChange();

        emit FeeDistributorUpdated($.feeDistributor = feeDistributor_);
    }

    /// @inheritdoc IPayerRegistry
    function updateMinimumDeposit() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        uint96 minimumDeposit_ = RegistryParameters.getUint96Parameter(parameterRegistry, minimumDepositParameterKey());

        if (minimumDeposit_ == 0) revert ZeroMinimumDeposit();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if ($.minimumDeposit == minimumDeposit_) revert NoChange();

        emit MinimumDepositUpdated($.minimumDeposit = minimumDeposit_);
    }

    /// @inheritdoc IPayerRegistry
    function updateWithdrawLockPeriod() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        uint32 withdrawLockPeriod_ = RegistryParameters.getUint32Parameter(
            parameterRegistry,
            withdrawLockPeriodParameterKey()
        );

        if (withdrawLockPeriod_ > _MAX_WITHDRAW_LOCK_PERIOD) {
            revert WithdrawLockPeriodTooHigh(withdrawLockPeriod_, _MAX_WITHDRAW_LOCK_PERIOD);
        }

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if (withdrawLockPeriod_ == $.withdrawLockPeriod) revert NoChange();

        emit WithdrawLockPeriodUpdated($.withdrawLockPeriod = withdrawLockPeriod_);
    }

    /// @inheritdoc IPayerRegistry
    function updatePauseStatus() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        bool paused_ = RegistryParameters.getBoolParameter(parameterRegistry, pausedParameterKey());
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if (paused_ == $.paused) revert NoChange();

        emit PauseStatusUpdated($.paused = paused_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayerRegistry
    function settlerParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerRegistry.settler";
    }

    /// @inheritdoc IPayerRegistry
    function feeDistributorParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerRegistry.feeDistributor";
    }

    /// @inheritdoc IPayerRegistry
    function minimumDepositParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerRegistry.minimumDeposit";
    }

    /// @inheritdoc IPayerRegistry
    function withdrawLockPeriodParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerRegistry.withdrawLockPeriod";
    }

    /// @inheritdoc IPayerRegistry
    function pausedParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerRegistry.paused";
    }

    /// @inheritdoc IPayerRegistry
    function migratorParameterKey() public pure returns (string memory key_) {
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
        uint96 tokenBalance_ = uint96(IERC20Like(feeToken).balanceOf(address(this)));

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
    ) external view returns (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_, uint24 nonce_) {
        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        return (
            $.payers[payer_].pendingWithdrawal,
            $.payers[payer_].withdrawableTimestamp,
            $.payers[payer_].withdrawalNonce
        );
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
     * @dev Transfers `amount_` of fee tokens from the caller to this contract to satisfy a deposit for `payer_`.
     */
    function _depositFeeToken(address payer_, uint96 amount_) internal {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IERC20Like(feeToken).transferFrom` nor `_deposit` can result in a reentrancy.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), amount_);
        _deposit(payer_, amount_);
    }

    /**
     * @dev Transfers `amount_` of fee tokens from the caller to this contract to satisfy a deposit for `payer_`.
     */
    function _depositFromUnderlying(address payer_, uint96 amount_) internal {
        // NOTE: There is no issue if the underlying fee token transfer results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy.
        SafeTransferLib.safeTransferFrom(_underlyingFeeToken, msg.sender, address(this), amount_);

        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IFeeTokenLike(feeToken).deposit` nor `_deposit` can result in a reentrancy.
        IFeeTokenLike(feeToken).deposit(amount_);
        _deposit(payer_, amount_);
    }

    /**
     * @dev Satisfies a deposit for `payer_`.
     */
    function _deposit(address payer_, uint96 amount_) internal whenNotPaused {
        if (_isZero(payer_)) revert ZeroPayer();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();

        if (amount_ < $.minimumDeposit) {
            revert InsufficientDeposit(amount_, $.minimumDeposit);
        }

        uint96 debtRepaid_ = _increaseBalance(payer_, amount_);

        $.totalDebt -= debtRepaid_;
        $.totalDeposits += _toInt104(amount_);

        // slither-disable-next-line reentrancy-events
        emit Deposit(payer_, amount_);
    }

    /**
     * @dev    Finalizes a pending withdrawal for the caller.
     * @param  recipient_         The address to send the withdrawal to.
     * @return pendingWithdrawal_ The amount of the pending withdrawal.
     */
    function _finalizeWithdrawal(address recipient_) internal whenNotPaused returns (uint96 pendingWithdrawal_) {
        if (_isZero(recipient_)) revert ZeroRecipient();

        PayerRegistryStorage storage $ = _getPayerRegistryStorage();
        Payer storage payer_ = $.payers[msg.sender];
        pendingWithdrawal_ = payer_.pendingWithdrawal;

        if (pendingWithdrawal_ == 0) revert NoPendingWithdrawal();
        if (payer_.balance < 0) revert PayerInDebt();

        // slither-disable-next-line timestamp
        if (block.timestamp < payer_.withdrawableTimestamp) {
            revert WithdrawalNotReady(uint32(block.timestamp), payer_.withdrawableTimestamp, payer_.withdrawalNonce);
        }

        delete payer_.pendingWithdrawal;
        delete payer_.withdrawableTimestamp;

        $.totalDeposits -= _toInt104(pendingWithdrawal_);

        emit WithdrawalFinalized(msg.sender, payer_.withdrawalNonce);
    }

    /**
     * @dev Uses a permit to approve the deposit of `amount_` of `token_` from the caller to this contract.
     * @dev Silently ignore a failing permit, as it may indicate that the permit was already used and/or the allowance
     *      has already been approved.
     */
    function _usePermit(address token_, uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) internal {
        // Ignore return value, as the permit may have already been used, and the allowance already approved.
        // slither-disable-next-line unchecked-lowlevel
        address(token_).call(
            abi.encodeWithSelector(
                IPermitErc20Like.permit.selector,
                msg.sender,
                address(this),
                amount_,
                deadline_,
                v_,
                r_,
                s_
            )
        );
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Returns the debt represented by a balance, if any.
     */
    function _getDebt(int104 balance_) internal pure returns (uint96 debt_) {
        return balance_ < 0 ? uint96(uint104(-balance_)) : 0;
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

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := input_
        }
    }

    function _revertIfNotSettler() internal view {
        if (msg.sender != _getPayerRegistryStorage().settler) revert NotSettler();
    }

    function _revertIfPaused() internal view {
        if (_getPayerRegistryStorage().paused) revert Paused();
    }
}
