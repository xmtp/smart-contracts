// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { PayerRegistryHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayerRegistryTests is Test {
    bytes internal constant _PAUSED_KEY = "xmtp.payerRegistry.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.payerRegistry.migrator";
    bytes internal constant _MINIMUM_DEPOSIT_KEY = "xmtp.payerRegistry.minimumDeposit";
    bytes internal constant _WITHDRAW_LOCK_PERIOD_KEY = "xmtp.payerRegistry.withdrawLockPeriod";
    bytes internal constant _SETTLER_KEY = "xmtp.payerRegistry.settler";
    bytes internal constant _FEE_DISTRIBUTOR_KEY = "xmtp.payerRegistry.feeDistributor";

    PayerRegistryHarness internal _registry;

    address internal _implementation;

    address internal _feeDistributor = makeAddr("feeDistributor");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _settler = makeAddr("settler");
    address internal _token = makeAddr("token");

    address internal _unauthorized = makeAddr("unauthorized");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _dave = makeAddr("dave");

    function setUp() external {
        _implementation = address(new PayerRegistryHarness(_parameterRegistry, _token));
        _registry = PayerRegistryHarness(address(new Proxy(_implementation)));

        _registry.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IPayerRegistry.ZeroParameterRegistry.selector);
        new PayerRegistryHarness(address(0), _token);
    }

    function test_constructor_zeroToken() external {
        vm.expectRevert(IPayerRegistry.ZeroToken.selector);
        new PayerRegistryHarness(_parameterRegistry, address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(keccak256(_registry.minimumDepositParameterKey()), keccak256(_MINIMUM_DEPOSIT_KEY));
        assertEq(keccak256(_registry.withdrawLockPeriodParameterKey()), keccak256(_WITHDRAW_LOCK_PERIOD_KEY));
        assertEq(keccak256(_registry.settlerParameterKey()), keccak256(_SETTLER_KEY));
        assertEq(keccak256(_registry.feeDistributorParameterKey()), keccak256(_FEE_DISTRIBUTOR_KEY));
        assertEq(keccak256(_registry.pausedParameterKey()), keccak256(_PAUSED_KEY));
        assertEq(keccak256(_registry.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertFalse(_registry.paused());
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.token(), _token);
        assertEq(_registry.settler(), address(0));
        assertEq(_registry.feeDistributor(), address(0));
        assertEq(_registry.minimumDeposit(), 0);
        assertEq(_registry.withdrawLockPeriod(), 0);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize();
    }

    /* ============ deposit ============ */

    function test_deposit_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, 0);
    }

    function test_deposit_insufficientDeposit() external {
        _registry.__setMinimumDeposit(10);

        vm.expectRevert(abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, 9, 10));

        vm.prank(_alice);
        _registry.deposit(_bob, 9);
    }

    function test_deposit_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, 1);
    }

    function test_deposit_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            ""
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, 1);
    }

    function test_deposit() external {
        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            abi.encode(true)
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.Deposit(_bob, 1);

        vm.prank(_alice);
        _registry.deposit(_bob, 1);

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.getBalance(_bob), int256(uint256(1)));
    }

    function testFuzz_deposit(int104 startingBalance_, uint96 amount_, uint96 minimumDeposit_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        minimumDeposit_ = uint96(_bound(minimumDeposit_, 0, type(uint96).max));
        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_ - _toInt104(amount_)));

        _registry.__setMinimumDeposit(minimumDeposit_);
        _registry.__setBalance(_bob, startingBalance_);
        _registry.__setTotalDeposits(startingBalance_);

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ + _toInt104(amount_);
        uint96 expectedTotalDebt_ = expectedBalance_ < 0 ? uint96(uint104(-expectedBalance_)) : 0;

        if (amount_ < minimumDeposit_) {
            vm.expectRevert(
                abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, amount_, minimumDeposit_)
            );
        } else {
            Utils.expectAndMockCall(
                _token,
                abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), amount_),
                abi.encode(true)
            );

            vm.expectEmit(address(_registry));
            emit IPayerRegistry.Deposit(_bob, amount_);
        }

        vm.prank(_alice);
        _registry.deposit(_bob, amount_);

        if (amount_ < minimumDeposit_) return;

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.getBalance(_bob), expectedBalance_);
        assertEq(_registry.totalDeposits(), expectedBalance_);
        assertEq(_registry.totalDebt(), expectedTotalDebt_);
    }

    /* ============ depositWithPermit ============ */

    function test_depositWithPermit_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.depositWithPermit(_bob, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_insufficientDeposit() external {
        _registry.__setMinimumDeposit(10);

        vm.expectRevert(abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, 9, 10));

        vm.prank(_alice);
        _registry.depositWithPermit(_bob, 9, 0, 0, 0, 0);
    }

    function test_depositWithPermit_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.depositWithPermit(_bob, 1, 0, 0, 0, 0);
    }

    function test_depositWithPermit_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            ""
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.depositWithPermit(_bob, 1, 0, 0, 0, 0);
    }

    function test_depositWithPermit() external {
        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_registry),
                1,
                0,
                0,
                0,
                0
            ),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_registry), 1),
            abi.encode(true)
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.Deposit(_bob, 1);

        vm.prank(_alice);
        _registry.depositWithPermit(_bob, 1, 0, 0, 0, 0);

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.getBalance(_bob), int256(uint256(1)));
    }

    /* ============ requestWithdrawal ============ */

    function test_requestWithdrawal_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.requestWithdrawal(0);
    }

    function test_requestWithdrawal_zeroWithdrawalAmount() external {
        vm.expectRevert(IPayerRegistry.ZeroWithdrawalAmount.selector);
        vm.prank(_alice);
        _registry.requestWithdrawal(0);
    }

    function test_requestWithdrawal_pendingWithdrawalExists() external {
        _registry.__setPendingWithdrawal(_alice, 1);

        vm.expectRevert(IPayerRegistry.PendingWithdrawalExists.selector);

        vm.prank(_alice);
        _registry.requestWithdrawal(1);
    }

    function test_requestWithdrawal_insufficientBalance() external {
        _registry.__setBalance(_alice, 10e6);

        vm.expectRevert(IPayerRegistry.InsufficientBalance.selector);

        vm.prank(_alice);
        _registry.requestWithdrawal(10e6 + 1);
    }

    function test_requestWithdrawal() external {
        _registry.__setBalance(_alice, 10e6);
        _registry.__setWithdrawLockPeriod(2 days);

        uint32 expectedPendingWithdrawableTimestamp_ = uint32(vm.getBlockTimestamp()) + 2 days;

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawalRequested(_alice, 10e6, expectedPendingWithdrawableTimestamp_);

        vm.prank(_alice);
        _registry.requestWithdrawal(10e6);

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.__getPendingWithdrawal(_alice), 10e6);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), expectedPendingWithdrawableTimestamp_);
    }

    function testFuzz_requestWithdrawal(int104 startingBalance_, uint96 amount_, uint32 withdrawLockPeriod_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_));
        withdrawLockPeriod_ = uint32(_bound(withdrawLockPeriod_, 0, 10 days));

        _registry.__setWithdrawLockPeriod(withdrawLockPeriod_);
        _registry.__setBalance(_alice, startingBalance_);
        _registry.__setTotalDeposits(startingBalance_);

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ - _toInt104(amount_);
        uint32 expectedPendingWithdrawableTimestamp_ = uint32(vm.getBlockTimestamp()) + withdrawLockPeriod_;
        uint96 expectedTotalDebt_ = expectedBalance_ < 0 ? uint96(uint104(-expectedBalance_)) : 0;

        if (amount_ == 0 || expectedBalance_ < 0) {
            vm.expectRevert();
        } else {
            vm.expectEmit(address(_registry));
            emit IPayerRegistry.WithdrawalRequested(_alice, amount_, expectedPendingWithdrawableTimestamp_);
        }

        vm.prank(_alice);
        _registry.requestWithdrawal(amount_);

        if (amount_ == 0 || expectedBalance_ < 0) return;

        assertEq(_registry.getBalance(_alice), expectedBalance_);
        assertEq(_registry.__getPendingWithdrawal(_alice), amount_);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), expectedPendingWithdrawableTimestamp_);
        assertEq(_registry.totalDebt(), expectedTotalDebt_);
    }

    /* ============ cancelWithdrawal ============ */

    function test_cancelWithdrawal_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.cancelWithdrawal();
    }

    function test_cancelWithdrawal_noPendingWithdrawal() external {
        vm.expectRevert(IPayerRegistry.NoPendingWithdrawal.selector);
        vm.prank(_alice);
        _registry.cancelWithdrawal();
    }

    function test_cancelWithdrawal() external {
        _registry.__setPendingWithdrawal(_alice, 10e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawalCancelled(_alice);

        vm.prank(_alice);
        _registry.cancelWithdrawal();

        assertEq(_registry.__getPendingWithdrawal(_alice), 0);
    }

    function testFuzz_cancelWithdrawal(int104 startingBalance_, uint96 pendingWithdrawal_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_ - _toInt104(pendingWithdrawal_)));

        _registry.__setBalance(_alice, startingBalance_);
        _registry.__setPendingWithdrawal(_alice, pendingWithdrawal_);
        _registry.__setPendingWithdrawableTimestamp(_alice, 1);
        _registry.__setTotalDeposits(startingBalance_ + _toInt104(pendingWithdrawal_));

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ + _toInt104(pendingWithdrawal_);
        uint96 expectedTotalDebt_ = expectedBalance_ < 0 ? uint96(uint104(-expectedBalance_)) : 0;

        if (pendingWithdrawal_ == 0) {
            vm.expectRevert(IPayerRegistry.NoPendingWithdrawal.selector);
        } else {
            vm.expectEmit(address(_registry));
            emit IPayerRegistry.WithdrawalCancelled(_alice);
        }

        vm.prank(_alice);
        _registry.cancelWithdrawal();

        if (pendingWithdrawal_ == 0) return;

        assertEq(_registry.__getPendingWithdrawal(_alice), 0);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), 0);
        assertEq(_registry.getBalance(_alice), expectedBalance_);
        assertEq(_registry.totalDeposits(), expectedBalance_);
        assertEq(_registry.totalDebt(), expectedTotalDebt_);
    }

    /* ============ finalizeWithdrawal ============ */

    function test_finalizeWithdrawal_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_noPendingWithdrawal() external {
        vm.expectRevert(IPayerRegistry.NoPendingWithdrawal.selector);
        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_payerInDebt() external {
        _registry.__setBalance(_alice, -1);
        _registry.__setPendingWithdrawal(_alice, 1);

        vm.expectRevert(IPayerRegistry.PayerInDebt.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_withdrawalNotReady() external {
        _registry.__setPendingWithdrawal(_alice, 1);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()) + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPayerRegistry.WithdrawalNotReady.selector,
                uint32(vm.getBlockTimestamp()),
                uint32(vm.getBlockTimestamp()) + 1
            )
        );

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_erc20TransferFailed_tokenReturnsFalse() external {
        _registry.__setPendingWithdrawal(_alice, 1);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        vm.mockCall(_token, abi.encodeWithSignature("transfer(address,uint256)", _alice, 1), abi.encode(false));

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_erc20TransferFailed_tokenReverts() external {
        _registry.__setPendingWithdrawal(_alice, 1);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        vm.mockCallRevert(_token, abi.encodeWithSignature("transfer(address,uint256)", _alice, 1), "");

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal() external {
        _registry.__setPendingWithdrawal(_alice, 10e6);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 10e6),
            abi.encode(true)
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawalFinalized(_alice);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);

        assertEq(_registry.__getPendingWithdrawal(_alice), 0);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), 0);
    }

    /* ============ settleUsage ============ */

    function test_settleUsage_notSettler() external {
        _registry.__setSettler(_settler);

        vm.expectRevert(IPayerRegistry.NotSettler.selector);
        vm.prank(_unauthorized);
        _registry.settleUsage(new IPayerRegistry.PayerFee[](0));
    }

    function test_settleUsage_paused() external {
        _registry.__setSettler(_settler);
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_settler);
        _registry.settleUsage(new IPayerRegistry.PayerFee[](0));
    }

    function test_settleUsage() external {
        IPayerRegistry.PayerFee[] memory payerFees_ = new IPayerRegistry.PayerFee[](3);
        payerFees_[0] = IPayerRegistry.PayerFee({ payer: _alice, fee: 10e6 });
        payerFees_[1] = IPayerRegistry.PayerFee({ payer: _bob, fee: 20e6 });
        payerFees_[2] = IPayerRegistry.PayerFee({ payer: _charlie, fee: 30e6 });

        _registry.__setSettler(_settler);

        _registry.__setBalance(_alice, 30e6);
        _registry.__setBalance(_bob, 10e6);
        _registry.__setBalance(_charlie, -10e6);

        _registry.__setTotalDeposits(30e6 + 10e6 - 10e6); // Sum of Alice, Bob, and Charlie's balances.
        _registry.__setTotalDebt(10e6); // Charlie's debt.

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_alice, 10e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_bob, 20e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_charlie, 30e6);

        vm.prank(_settler);
        uint96 feesSettled_ = _registry.settleUsage(payerFees_);

        assertEq(feesSettled_, 10e6 + 20e6 + 30e6);

        assertEq(_registry.getBalance(_alice), 30e6 - 10e6);
        assertEq(_registry.getBalance(_bob), 10e6 - 20e6);
        assertEq(_registry.getBalance(_charlie), -10e6 - 30e6);

        // Expected total deposits is (Sum of starting balances) minus (Sum of fees).
        assertEq(_registry.totalDeposits(), (30e6 + 10e6 - 10e6) - (10e6 + 20e6 + 30e6));

        // Expected total debt is (Charlie's starting debt) plus (Sum of Bob and Charlies's addition incurred debt),
        assertEq(_registry.totalDebt(), (10e6) + (10e6 + 30e6));
    }

    // TODO: testFuzz_settleUsage

    /* ============ sendExcessToFeeDistributor ============ */

    function test_sendExcessToFeeDistributor_noExcess() external {
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(_token, abi.encodeWithSignature("balanceOf(address)", address(_registry)), abi.encode(100e6));

        vm.expectRevert(IPayerRegistry.NoExcess.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_zeroFeeDistributor() external {
        _registry.__setFeeDistributor(address(0));
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(_token, abi.encodeWithSignature("balanceOf(address)", address(_registry)), abi.encode(200e6));

        vm.expectRevert(IPayerRegistry.ZeroFeeDistributor.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_erc20TransferFailed_tokenReturnsFalse() external {
        _registry.__setFeeDistributor(_feeDistributor);
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(_token, abi.encodeWithSignature("balanceOf(address)", address(_registry)), abi.encode(200e6));

        vm.mockCall(
            _token,
            abi.encodeWithSignature("transfer(address,uint256)", _feeDistributor, 100e6),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_erc20TransferFailed_tokenReverts() external {
        _registry.__setFeeDistributor(_feeDistributor);
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(_token, abi.encodeWithSignature("balanceOf(address)", address(_registry)), abi.encode(200e6));

        vm.mockCallRevert(_token, abi.encodeWithSignature("transfer(address,uint256)", _feeDistributor, 100e6), "");

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor() external {
        _registry.__setFeeDistributor(_feeDistributor);
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_registry)),
            abi.encode(200e6)
        );

        vm.expectCall(_token, abi.encodeWithSignature("transfer(address,uint256)", _feeDistributor, 100e6));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.ExcessTransferred(100e6);

        _registry.sendExcessToFeeDistributor();
    }

    /* ============ updateSettler ============ */

    function test_updateSettler_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _SETTLER_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.updateSettler();
    }

    function test_updateSettler_zeroSettler() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _SETTLER_KEY, 0);

        vm.expectRevert(IPayerRegistry.ZeroSettler.selector);

        _registry.updateSettler();
    }

    function test_updateSettler_noChange() external {
        _registry.__setSettler(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _SETTLER_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateSettler();
    }

    function test_updateSettler() external {
        _registry.__setSettler(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _SETTLER_KEY,
            bytes32(uint256(uint160(address(2))))
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.SettlerUpdated(address(2));

        _registry.updateSettler();

        assertEq(_registry.settler(), address(2));
    }

    /* ============ updateFeeDistributor ============ */

    function test_updateFeeDistributor_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _FEE_DISTRIBUTOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.updateFeeDistributor();
    }

    function test_updateFeeDistributor_zeroFeeDistributor() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _FEE_DISTRIBUTOR_KEY, 0);

        vm.expectRevert(IPayerRegistry.ZeroFeeDistributor.selector);

        _registry.updateFeeDistributor();
    }

    function test_updateFeeDistributor_noChange() external {
        _registry.__setFeeDistributor(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _FEE_DISTRIBUTOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateFeeDistributor();
    }

    function test_updateFeeDistributor() external {
        _registry.__setFeeDistributor(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _FEE_DISTRIBUTOR_KEY,
            bytes32(uint256(uint160(address(2))))
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.FeeDistributorUpdated(address(2));

        _registry.updateFeeDistributor();

        assertEq(_registry.feeDistributor(), address(2));
    }

    /* ============ updateMinimumDeposit ============ */

    function test_updateMinimumDeposit_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MINIMUM_DEPOSIT_KEY,
            bytes32(uint256(type(uint96).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.updateMinimumDeposit();
    }

    function test_updateMinimumDeposit_zeroMinimumDeposit() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MINIMUM_DEPOSIT_KEY, 0);

        vm.expectRevert(IPayerRegistry.ZeroMinimumDeposit.selector);

        _registry.updateMinimumDeposit();
    }

    function test_updateMinimumDeposit_noChange() external {
        _registry.__setMinimumDeposit(1);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MINIMUM_DEPOSIT_KEY, bytes32(uint256(1)));

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateMinimumDeposit();
    }

    function test_updateMinimumDeposit() external {
        _registry.__setMinimumDeposit(1);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MINIMUM_DEPOSIT_KEY, bytes32(uint256(2)));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.MinimumDepositUpdated(2);

        _registry.updateMinimumDeposit();

        assertEq(_registry.minimumDeposit(), 2);
    }

    /* ============ updateWithdrawLockPeriod ============ */

    function test_updateWithdrawLockPeriod_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _WITHDRAW_LOCK_PERIOD_KEY,
            bytes32(uint256(type(uint32).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.updateWithdrawLockPeriod();
    }

    function test_updateWithdrawLockPeriod_noChange() external {
        _registry.__setWithdrawLockPeriod(1);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _WITHDRAW_LOCK_PERIOD_KEY, bytes32(uint256(1)));

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateWithdrawLockPeriod();
    }

    function test_updateWithdrawLockPeriod() external {
        _registry.__setWithdrawLockPeriod(1);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _WITHDRAW_LOCK_PERIOD_KEY, bytes32(uint256(2)));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawLockPeriodUpdated(2);

        _registry.updateWithdrawLockPeriod();

        assertEq(_registry.withdrawLockPeriod(), 2);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _registry.updatePauseStatus();

        assertTrue(_registry.paused());

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        _registry.updatePauseStatus();

        assertFalse(_registry.paused());
    }

    /* ============ totalWithdrawable ============ */

    function test_totalWithdrawable() external {
        _registry.__setTotalDeposits(120e6); // Alice, Bob, and Charlie have a balance of 40 each.
        _registry.__setTotalDebt(0); // Neither have debts.

        assertEq(_registry.totalWithdrawable(), 120e6); // ALice, Bob, and Charlie can withdraw.

        _registry.__setTotalDeposits(40e6); // Alice and Bob have a balance of 40 each, Charlie has 40 debt.
        _registry.__setTotalDebt(40e6);

        assertEq(_registry.totalWithdrawable(), 80e6); // Alice and Bob can withdraw.

        _registry.__setTotalDeposits(-40e6); // Alice has a balance of 40 each, Bob and Charlie have 40 debt each.
        _registry.__setTotalDebt(80e6);

        assertEq(_registry.totalWithdrawable(), 40e6); // Alice can withdraw.

        _registry.__setTotalDeposits(-120e6); // Alice, Bob, and Charlie have 40 debt each.
        _registry.__setTotalDebt(120e6);

        assertEq(_registry.totalWithdrawable(), 0e6); // No one can withdraw.
    }

    /* ============ getBalances ============ */

    function test_getBalances() external {
        address[] memory payers = new address[](4);
        payers[0] = _alice;
        payers[1] = _bob;
        payers[2] = _charlie;
        payers[3] = _dave;

        _registry.__setBalance(_alice, 10e6);
        _registry.__setBalance(_bob, 20e6);
        _registry.__setBalance(_charlie, 30e6);
        _registry.__setBalance(_dave, 40e6);

        int104[] memory balances_ = _registry.getBalances(payers);

        assertEq(balances_.length, 4);
        assertEq(balances_[0], 10e6);
        assertEq(balances_[1], 20e6);
        assertEq(balances_[2], 30e6);
        assertEq(balances_[3], 40e6);
    }

    /* ============ getPendingWithdrawal ============ */

    function test_getPendingWithdrawal() external {
        _registry.__setPendingWithdrawal(_alice, 100);
        _registry.__setPendingWithdrawableTimestamp(_alice, 200);

        (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_) = _registry.getPendingWithdrawal(_alice);

        assertEq(pendingWithdrawal_, 100);
        assertEq(withdrawableTimestamp_, 200);
    }

    /* ============ excess ============ */

    function test_excess() external {
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 0); // 100 withdrawable, so none of balance is excess

        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_registry)),
            abi.encode(200e6)
        );

        assertEq(_registry.excess(), 100e6); // 100 withdrawable, so 100 of balance is excess.

        _registry.__setTotalDeposits(-100e6);
        _registry.__setTotalDebt(100e6);

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 100e6); // 0 withdrawable, so 100 of balance is excess.

        _registry.__setTotalDeposits(-50e6);
        _registry.__setTotalDebt(100e6);

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 50e6); // 50 withdrawable, so 50 of balance is excess.
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registry.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(0)));
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _registry.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = makeAddr("migrator");

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        bytes memory revertData_ = abi.encodeWithSignature("Failed()");

        vm.mockCallRevert(migrator_, bytes(""), revertData_);

        vm.expectRevert(abi.encodeWithSelector(IMigratable.MigrationFailed.selector, migrator_, revertData_));

        _registry.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _registry.migrate();
    }

    function test_migrate() external {
        _registry.__setSettler(_settler);
        _registry.__setFeeDistributor(_feeDistributor);
        _registry.__setMinimumDeposit(100);
        _registry.__setWithdrawLockPeriod(50);

        address newImplementation_ = address(new PayerRegistryHarness(_parameterRegistry, _token));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_registry));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation_);

        _registry.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_registry)), newImplementation_);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.token(), _token);
        assertEq(_registry.settler(), _settler);
        assertEq(_registry.feeDistributor(), _feeDistributor);
        assertEq(_registry.minimumDeposit(), 100);
        assertEq(_registry.withdrawLockPeriod(), 50);
    }

    /* ============ helper functions ============ */

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        assembly {
            output_ := input_
        }
    }
}
