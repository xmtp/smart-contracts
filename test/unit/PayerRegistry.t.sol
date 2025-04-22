// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";

import { PayerRegistryHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockErc20, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayerRegistryTests is Test, Utils {
    bytes internal constant _PAUSED_KEY = "xmtp.payerRegistry.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.payerRegistry.migrator";
    bytes internal constant _MINIMUM_DEPOSIT_KEY = "xmtp.payerRegistry.minimumDeposit";
    bytes internal constant _WITHDRAW_LOCK_PERIOD_KEY = "xmtp.payerRegistry.withdrawLockPeriod";
    bytes internal constant _SETTLER_KEY = "xmtp.payerRegistry.settler";
    bytes internal constant _FEE_DISTRIBUTOR_KEY = "xmtp.payerRegistry.feeDistributor";

    PayerRegistryHarness internal _registry;

    address internal _implementation;
    address internal _parameterRegistry;
    address internal _token;

    address internal _settler = makeAddr("settler");
    address internal _feeDistributor = makeAddr("feeDistributor");
    address internal _unauthorized = makeAddr("unauthorized");
    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _dave = makeAddr("dave");

    uint96 internal _minimumDeposit = 10e6;
    uint32 internal _withdrawLockPeriod = 2 days;

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _token = address(new MockErc20());

        _implementation = address(new PayerRegistryHarness(_parameterRegistry, _token));

        _mockParameterRegistryCall(_MINIMUM_DEPOSIT_KEY, _minimumDeposit);
        _mockParameterRegistryCall(_WITHDRAW_LOCK_PERIOD_KEY, _withdrawLockPeriod);
        _mockParameterRegistryCall(_SETTLER_KEY, _settler);
        _mockParameterRegistryCall(_FEE_DISTRIBUTOR_KEY, _feeDistributor);

        _registry = PayerRegistryHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(IPayerRegistry.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistryAddress() external {
        vm.expectRevert(IPayerRegistry.ZeroParameterRegistryAddress.selector);

        new PayerRegistryHarness(address(0), _token);
    }

    function test_constructor_zeroTokenAddress() external {
        vm.expectRevert(IPayerRegistry.ZeroTokenAddress.selector);

        new PayerRegistryHarness(_parameterRegistry, address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_registry)), _implementation);
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
        assertEq(_registry.settler(), _settler);
        assertEq(_registry.feeDistributor(), _feeDistributor);
        assertEq(_registry.minimumDeposit(), _minimumDeposit);
        assertEq(_registry.withdrawLockPeriod(), _withdrawLockPeriod);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize();
    }

    /* ============ deposit to self ============ */

    function test_deposit_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.deposit(0);
    }

    function test_deposit_toSelf_insufficientDeposit() external {
        vm.expectRevert(
            abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, _minimumDeposit - 1, _minimumDeposit)
        );

        vm.prank(_alice);
        _registry.deposit(_minimumDeposit - 1);
    }

    function test_deposit_toSelf_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_minimumDeposit);
    }

    function test_deposit_toSelf_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit),
            ""
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_minimumDeposit);
    }

    function test_deposit_toSelf() external {
        vm.expectCall(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit)
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.Deposit(_alice, _minimumDeposit);

        vm.prank(_alice);
        _registry.deposit(_minimumDeposit);

        assertEq(_registry.getBalance(_alice), int256(uint256(_minimumDeposit)));
    }

    function testFuzz_deposit_toSelf(int104 startingBalance_, uint96 amount_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_ - _toInt104(amount_)));

        _registry.__setBalance(_alice, startingBalance_);
        _registry.__setTotalDeposits(startingBalance_);

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ + _toInt104(amount_);
        uint96 expectedTotalDebt_ = expectedBalance_ < 0 ? uint96(uint104(-expectedBalance_)) : 0;

        if (amount_ < _minimumDeposit) {
            vm.expectRevert(
                abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, amount_, _minimumDeposit)
            );
        } else {
            vm.expectEmit(address(_registry));
            emit IPayerRegistry.Deposit(_alice, amount_);
        }

        vm.prank(_alice);
        _registry.deposit(amount_);

        if (amount_ < _minimumDeposit) return;

        assertEq(_registry.getBalance(_alice), expectedBalance_);
        assertEq(_registry.totalDeposits(), expectedBalance_);
        assertEq(_registry.totalDebt(), expectedTotalDebt_);
    }

    /* ============ deposit to payer ============ */

    function test_deposit_toPayer_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, 0);
    }

    function test_deposit_toPayer_insufficientDeposit() external {
        vm.expectRevert(
            abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, _minimumDeposit - 1, _minimumDeposit)
        );

        vm.prank(_alice);
        _registry.deposit(_bob, _minimumDeposit - 1);
    }

    function test_deposit_toPayer_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, _minimumDeposit);
    }

    function test_deposit_toPayer_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit),
            ""
        );

        vm.expectRevert(IPayerRegistry.TransferFromFailed.selector);

        vm.prank(_alice);
        _registry.deposit(_bob, _minimumDeposit);
    }

    function test_deposit_toPayer() external {
        vm.expectCall(
            _token,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_registry), _minimumDeposit)
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.Deposit(_bob, _minimumDeposit);

        vm.prank(_alice);
        _registry.deposit(_bob, _minimumDeposit);

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.getBalance(_bob), int256(uint256(_minimumDeposit)));
    }

    function testFuzz_deposit_toPayer(int104 startingBalance_, uint96 amount_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_ - _toInt104(amount_)));

        _registry.__setBalance(_bob, startingBalance_);
        _registry.__setTotalDeposits(startingBalance_);

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ + _toInt104(amount_);
        uint96 expectedTotalDebt_ = expectedBalance_ < 0 ? uint96(uint104(-expectedBalance_)) : 0;

        if (amount_ < _minimumDeposit) {
            vm.expectRevert(
                abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, amount_, _minimumDeposit)
            );
        } else {
            vm.expectEmit(address(_registry));
            emit IPayerRegistry.Deposit(_bob, amount_);
        }

        vm.prank(_alice);
        _registry.deposit(_bob, amount_);

        if (amount_ < _minimumDeposit) return;

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.getBalance(_bob), expectedBalance_);
        assertEq(_registry.totalDeposits(), expectedBalance_);
        assertEq(_registry.totalDebt(), expectedTotalDebt_);
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

        uint32 expectedPendingWithdrawableTimestamp_ = uint32(vm.getBlockTimestamp()) + _withdrawLockPeriod;

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawalRequested(_alice, 10e6, expectedPendingWithdrawableTimestamp_);

        vm.prank(_alice);
        _registry.requestWithdrawal(10e6);

        assertEq(_registry.getBalance(_alice), 0);
        assertEq(_registry.__getPendingWithdrawal(_alice), 10e6);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), expectedPendingWithdrawableTimestamp_);
    }

    function testFuzz_requestWithdrawal(int104 startingBalance_, uint96 amount_) external {
        int104 limit_ = int104(uint104(type(uint96).max));

        startingBalance_ = int104(_bound(startingBalance_, -limit_, limit_));

        _registry.__setBalance(_alice, startingBalance_);
        _registry.__setTotalDeposits(startingBalance_);

        if (startingBalance_ < 0) {
            _registry.__setTotalDebt(uint104(-startingBalance_));
        }

        int104 expectedBalance_ = startingBalance_ - _toInt104(amount_);
        uint32 expectedPendingWithdrawableTimestamp_ = uint32(vm.getBlockTimestamp()) + _withdrawLockPeriod;
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

        vm.mockCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 1), abi.encode(false));

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_erc20TransferFailed_tokenReverts() external {
        _registry.__setPendingWithdrawal(_alice, 1);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        vm.mockCallRevert(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 1), "");

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal() external {
        _registry.__setPendingWithdrawal(_alice, 10e6);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        vm.expectCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 10e6));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawalFinalized(_alice);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);

        assertEq(_registry.__getPendingWithdrawal(_alice), 0);
        assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), 0);
    }

    /* ============ settleUsage ============ */

    function test_settleUsage_notSettler() external {
        vm.expectRevert(IPayerRegistry.NotSettler.selector);

        vm.prank(_unauthorized);
        _registry.settleUsage(new address[](0), new uint96[](0));
    }

    function test_settleUsage_paused() external {
        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.Paused.selector);

        vm.prank(_settler);
        _registry.settleUsage(new address[](0), new uint96[](0));
    }

    function test_settleUsage_arrayLengthMismatch() external {
        vm.expectRevert(IPayerRegistry.ArrayLengthMismatch.selector);

        vm.prank(_settler);
        _registry.settleUsage(new address[](0), new uint96[](1));
    }

    function test_settleUsage() external {
        address[] memory payers = new address[](3);
        payers[0] = _alice;
        payers[1] = _bob;
        payers[2] = _charlie;

        _registry.__setBalance(_alice, 30e6);
        _registry.__setBalance(_bob, 10e6);
        _registry.__setBalance(_charlie, -10e6);

        _registry.__setTotalDeposits(30e6 + 10e6 - 10e6); // Sum of Alice, Bob, and Charlie's balances.
        _registry.__setTotalDebt(10e6); // Charlie's debt.

        uint96[] memory fees = new uint96[](3);
        fees[0] = 10e6;
        fees[1] = 20e6;
        fees[2] = 30e6;

        // TODO: `_expectAndMockCall`.
        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(30e6 + 10e6) // Sum of positive balances (i.e. that can be withdrawn before fees are charged).
        );

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_alice, 10e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_bob, 20e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_charlie, 30e6);

        vm.prank(_settler);
        _registry.settleUsage(payers, fees);

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

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(100e6)
        );

        vm.expectRevert(IPayerRegistry.NoExcess.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_ZeroFeeDistributorAddress() external {
        _registry.__setFeeDistributor(address(0));
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(200e6)
        );

        vm.expectRevert(IPayerRegistry.ZeroFeeDistributorAddress.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_erc20TransferFailed_tokenReturnsFalse() external {
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(200e6)
        );

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 100e6),
            abi.encode(false)
        );

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor_erc20TransferFailed_tokenReverts() external {
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(200e6)
        );

        vm.mockCallRevert(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 100e6), "");

        vm.expectRevert(IPayerRegistry.TransferFailed.selector);

        _registry.sendExcessToFeeDistributor();
    }

    function test_sendExcessToFeeDistributor() external {
        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        // TODO: `_expectAndMockCall`.
        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(200e6)
        );

        vm.expectCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 100e6));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.ExcessTransferred(100e6);

        _registry.sendExcessToFeeDistributor();
    }

    /* ============ updateSettler ============ */

    function test_updateSettler_zeroSettlerAddress() external {
        _mockParameterRegistryCall(_SETTLER_KEY, address(0));

        vm.expectRevert(IPayerRegistry.ZeroSettlerAddress.selector);

        _registry.updateSettler();
    }

    function test_updateSettler_noChange() external {
        _registry.__setSettler(address(1));

        _mockParameterRegistryCall(_SETTLER_KEY, address(1));

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateSettler();
    }

    function test_updateSettler() external {
        _registry.__setSettler(address(1));

        _mockParameterRegistryCall(_SETTLER_KEY, address(2));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.SettlerUpdated(address(2));

        _registry.updateSettler();

        assertEq(_registry.settler(), address(2));
    }

    /* ============ updateFeeDistributor ============ */

    function test_updateFeeDistributor_zeroFeeDistributorAddress() external {
        _mockParameterRegistryCall(_FEE_DISTRIBUTOR_KEY, address(0));

        vm.expectRevert(IPayerRegistry.ZeroFeeDistributorAddress.selector);

        _registry.updateFeeDistributor();
    }

    function test_updateFeeDistributor_noChange() external {
        _registry.__setFeeDistributor(address(1));

        _mockParameterRegistryCall(_FEE_DISTRIBUTOR_KEY, address(1));

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateFeeDistributor();
    }

    function test_updateFeeDistributor() external {
        _registry.__setFeeDistributor(address(1));

        _mockParameterRegistryCall(_FEE_DISTRIBUTOR_KEY, address(2));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.FeeDistributorUpdated(address(2));

        _registry.updateFeeDistributor();

        assertEq(_registry.feeDistributor(), address(2));
    }

    /* ============ updateMinimumDeposit ============ */

    function test_updateMinimumDeposit_zeroMinimumDeposit() external {
        _mockParameterRegistryCall(_MINIMUM_DEPOSIT_KEY, uint256(0));

        vm.expectRevert(IPayerRegistry.ZeroMinimumDeposit.selector);

        _registry.updateMinimumDeposit();
    }

    function test_updateMinimumDeposit_noChange() external {
        _registry.__setMinimumDeposit(1);

        _mockParameterRegistryCall(_MINIMUM_DEPOSIT_KEY, 1);

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateMinimumDeposit();
    }

    function test_updateMinimumDeposit() external {
        _registry.__setMinimumDeposit(1);

        _mockParameterRegistryCall(_MINIMUM_DEPOSIT_KEY, uint256(2));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.MinimumDepositUpdated(2);

        _registry.updateMinimumDeposit();

        assertEq(_registry.minimumDeposit(), 2);
    }

    /* ============ updateWithdrawLockPeriod ============ */

    function test_updateWithdrawLockPeriod_noChange() external {
        _registry.__setWithdrawLockPeriod(1);

        _mockParameterRegistryCall(_WITHDRAW_LOCK_PERIOD_KEY, 1);

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updateWithdrawLockPeriod();
    }

    function test_updateWithdrawLockPeriod() external {
        _registry.__setWithdrawLockPeriod(1);

        _mockParameterRegistryCall(_WITHDRAW_LOCK_PERIOD_KEY, 2);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawLockPeriodUpdated(2);

        _registry.updateWithdrawLockPeriod();

        assertEq(_registry.withdrawLockPeriod(), 2);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_noChange() external {
        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updatePauseStatus();

        _mockParameterRegistryCall(_PAUSED_KEY, true);

        _registry.__setPauseStatus(true);

        vm.expectRevert(IPayerRegistry.NoChange.selector);

        _registry.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.PauseStatusUpdated(true);

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_PAUSED_KEY, true);

        _registry.updatePauseStatus();

        assertTrue(_registry.paused());

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.PauseStatusUpdated(false);

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_PAUSED_KEY, false);

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

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 0); // 100 withdrawable, so none of balance is excess

        _registry.__setTotalDeposits(100e6);
        _registry.__setTotalDebt(0);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(200e6)
        );

        assertEq(_registry.excess(), 100e6); // 100 withdrawable, so 100 of balance is excess.

        _registry.__setTotalDeposits(-100e6);
        _registry.__setTotalDebt(100e6);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 100e6); // 0 withdrawable, so 100 of balance is excess.

        _registry.__setTotalDeposits(-50e6);
        _registry.__setTotalDebt(100e6);

        vm.mockCall(
            _token,
            abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)),
            abi.encode(100e6)
        );

        assertEq(_registry.excess(), 50e6); // 50 withdrawable, so 50 of balance is excess.
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _registry.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _registry.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockParameterRegistryCall(_MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _registry.migrate();
    }

    function test_migrate() external {
        _registry.__setMinimumDeposit(100);
        _registry.__setWithdrawLockPeriod(50);

        address newImplementation_ = address(new PayerRegistryHarness(_parameterRegistry, _token));
        address migrator_ = address(new MockMigrator(newImplementation_));

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_registry));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation_);

        _registry.migrate();

        assertEq(_getImplementationFromSlot(address(_registry)), newImplementation_);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.token(), _token);
        assertEq(_registry.settler(), _settler);
        assertEq(_registry.feeDistributor(), _feeDistributor);
        assertEq(_registry.minimumDeposit(), 100);
        assertEq(_registry.withdrawLockPeriod(), 50);
    }

    /* ============ helper functions ============ */

    function _mockParameterRegistryCall(bytes memory key_, address value_) internal {
        _mockParameterRegistryCall(key_, bytes32(uint256(uint160(value_))));
    }

    function _mockParameterRegistryCall(bytes memory key_, bool value_) internal {
        _mockParameterRegistryCall(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function _mockParameterRegistryCall(bytes memory key_, uint256 value_) internal {
        _mockParameterRegistryCall(key_, bytes32(value_));
    }

    function _mockParameterRegistryCall(bytes memory key_, bytes32 value_) internal {
        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", key_), abi.encode(value_));
    }

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        assembly {
            output_ := input_
        }
    }
}
