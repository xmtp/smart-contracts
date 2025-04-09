// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC1967 } from "../../lib/oz/contracts/interfaces/IERC1967.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "../../lib/oz-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";

import { PayerRegistryHarness } from "../utils/Harnesses.sol";
import { MockErc20 } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayerRegistryTests is Test, Utils {
    address internal _implementation;

    PayerRegistryHarness internal _registry;

    address internal _token;

    address internal _admin = makeAddr("admin");
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
        _token = address(new MockErc20());

        _implementation = address(new PayerRegistryHarness(_token));

        _registry = PayerRegistryHarness(
            address(
                new ERC1967Proxy(
                    _implementation,
                    abi.encodeWithSelector(
                        IPayerRegistry.initialize.selector,
                        _admin,
                        _settler,
                        _feeDistributor,
                        _minimumDeposit,
                        _withdrawLockPeriod
                    )
                )
            )
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroTokenAddress() external {
        vm.expectRevert(IPayerRegistry.ZeroTokenAddress.selector);

        new PayerRegistryHarness(address(0));
    }

    /* ============ initializer ============ */

    function test_initializer_zeroAdminAddress() external {
        vm.expectRevert(IPayerRegistry.ZeroAdminAddress.selector);

        new ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(IPayerRegistry.initialize.selector, address(0), address(0), address(0), 0, 0)
        );
    }

    function test_initializer_zeroSettler() external {
        vm.expectRevert(IPayerRegistry.ZeroSettlerAddress.selector);

        new ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(IPayerRegistry.initialize.selector, address(1), address(0), address(0), 0, 0)
        );
    }

    function test_initializer_zeroFeeDistributor() external {
        vm.expectRevert(IPayerRegistry.ZeroFeeDistributorAddress.selector);

        new ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(IPayerRegistry.initialize.selector, address(1), address(1), address(0), 0, 0)
        );
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.token(), _token);
        assertEq(_registry.admin(), _admin);
        assertEq(_registry.settler(), _settler);
        assertEq(_registry.feeDistributor(), _feeDistributor);
        assertEq(_registry.minimumDeposit(), _minimumDeposit);
        assertEq(_registry.withdrawLockPeriod(), _withdrawLockPeriod);
    }

    /* ============ initialize ============ */

    function test_invalid_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize(address(0), address(0), address(0), 0, 0);
    }

    /* ============ deposit to self ============ */

    function test_deposit_toSelf_insufficientDeposit() external {
        vm.expectRevert(
            abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, _minimumDeposit - 1, _minimumDeposit)
        );

        vm.prank(_alice);
        _registry.deposit(_minimumDeposit - 1);
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

    function test_deposit_toPayer_insufficientDeposit() external {
        vm.expectRevert(
            abi.encodeWithSelector(IPayerRegistry.InsufficientDeposit.selector, _minimumDeposit - 1, _minimumDeposit)
        );

        vm.prank(_alice);
        _registry.deposit(_bob, _minimumDeposit - 1);
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

        vm.expectRevert(IPayerRegistry.ERC20TransferFailed.selector);

        vm.prank(_alice);
        _registry.finalizeWithdrawal(_alice);
    }

    function test_finalizeWithdrawal_erc20TransferFailed_tokenReverts() external {
        _registry.__setPendingWithdrawal(_alice, 1);
        _registry.__setWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

        vm.mockCallRevert(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 1), hex"");

        vm.expectRevert(IPayerRegistry.ERC20TransferFailed.selector);

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

    function test_settleUsage_arrayLengthMismatch() external {
        vm.expectRevert(IPayerRegistry.ArrayLengthMismatch.selector);

        vm.prank(_settler);
        _registry.settleUsage(new address[](0), new uint96[](1));
    }

    function test_settleUsage_erc20TransferFailed_tokenReturnsFalse() external {
        vm.mockCall(_token, abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)), abi.encode(1));
        vm.mockCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 1), abi.encode(false));

        vm.expectRevert(IPayerRegistry.ERC20TransferFailed.selector);

        vm.prank(_settler);
        _registry.settleUsage(new address[](0), new uint96[](0));
    }

    function test_settleUsage_erc20TransferFailed_tokenReverts() external {
        vm.mockCall(_token, abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)), abi.encode(1));
        vm.mockCallRevert(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 1), hex"");

        vm.expectRevert(IPayerRegistry.ERC20TransferFailed.selector);

        vm.prank(_settler);
        _registry.settleUsage(new address[](0), new uint96[](0));
    }

    function test_settleUsage_zeroFeeDistributor() external {
        address[] memory payers = new address[](1);
        payers[0] = _alice;

        _registry.__setBalance(_alice, 30e6);
        _registry.__setTotalDeposits(30e6);

        uint96[] memory fees = new uint96[](1);
        fees[0] = 10e6;

        // TODO: `_expectAndMockCall`.
        vm.mockCall(_token, abi.encodeWithSelector(MockErc20.balanceOf.selector, address(_registry)), abi.encode(30e6));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_alice, 10e6);

        vm.prank(_settler);
        _registry.settleUsage(payers, fees);

        assertEq(_registry.getBalance(_alice), 20e6);
        assertEq(_registry.totalDeposits(), 20e6);
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

        // The contract's token balance (`30e6 + 10e6`, see above) minus Alice's withdrawable amount.
        vm.expectCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _feeDistributor, 30e6 + 10e6 - 20e6));

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_alice, 10e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_bob, 20e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.UsageSettled(_charlie, 30e6);

        vm.expectEmit(address(_registry));
        emit IPayerRegistry.FeesTransferred(20e6);

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

    /* ============ pause ============ */

    function test_pause() external {
        vm.expectEmit(address(_registry));
        emit PausableUpgradeable.Paused(_admin);

        vm.prank(_admin);
        _registry.pause();

        assertTrue(_registry.paused());
    }

    function test_pause_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.pause();
    }

    function test_pause_whenPaused() external {
        _registry.__pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(_admin);
        _registry.pause();
    }

    /* ============ unpause ============ */

    function test_unpause() external {
        _registry.__pause();

        vm.expectEmit(address(_registry));
        emit PausableUpgradeable.Unpaused(_admin);

        vm.prank(_admin);
        _registry.unpause();

        assertFalse(_registry.paused());
    }

    function test_unpause_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.unpause();
    }

    function test_unpause_whenNotPaused() external {
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);

        vm.prank(_admin);
        _registry.unpause();
    }

    /* ============ setAdmin ============ */

    function test_setAdmin_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setAdmin(_unauthorized);
    }

    function test_setAdmin() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.AdminSet(_alice);

        vm.prank(_admin);
        _registry.setAdmin(_alice);

        assertEq(_registry.admin(), _alice);
    }

    /* ============ setSettler ============ */

    function test_setSettler_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setSettler(_unauthorized);
    }

    function test_setSettler() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.SettlerSet(_alice);

        vm.prank(_admin);
        _registry.setSettler(_alice);

        assertEq(_registry.settler(), _alice);
    }

    /* ============ setFeeDistributor ============ */

    function test_setFeeDistributor_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setFeeDistributor(_unauthorized);
    }

    function test_setFeeDistributor() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.FeeDistributorSet(_alice);

        vm.prank(_admin);
        _registry.setFeeDistributor(_alice);

        assertEq(_registry.feeDistributor(), _alice);
    }

    /* ============ setMinimumDeposit ============ */

    function test_setMinimumDeposit_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setMinimumDeposit(20e6);
    }

    function test_setMinimumDeposit() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.MinimumDepositSet(20e6);

        vm.prank(_admin);
        _registry.setMinimumDeposit(20e6);

        assertEq(_registry.minimumDeposit(), 20e6);
    }

    /* ============ setWithdrawLockPeriod ============ */

    function test_setWithdrawLockPeriod_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setWithdrawLockPeriod(3 days);
    }

    function test_setWithdrawLockPeriod() external {
        vm.expectEmit(address(_registry));
        emit IPayerRegistry.WithdrawLockPeriodSet(3 days);

        vm.prank(_admin);
        _registry.setWithdrawLockPeriod(3 days);

        assertEq(_registry.withdrawLockPeriod(), 3 days);
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

    /* ============ upgradeToAndCall ============ */

    function test_upgradeToAndCall_notAdmin() external {
        vm.expectRevert(IPayerRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall_zeroImplementationAddress() external {
        vm.expectRevert(IPayerRegistry.ZeroImplementationAddress.selector);

        vm.prank(_admin);
        _registry.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall() external {
        _registry.__setMinimumDeposit(20e6);
        _registry.__setWithdrawLockPeriod(3 days);

        address newImplementation = address(new PayerRegistryHarness(_token));

        // Authorized upgrade should succeed and emit UpgradeAuthorized event.
        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation);

        vm.prank(_admin);
        _registry.upgradeToAndCall(newImplementation, "");

        assertEq(_getImplementationFromSlot(address(_registry)), newImplementation);
        assertEq(_registry.minimumDeposit(), 20e6);
        assertEq(_registry.withdrawLockPeriod(), 3 days);
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy) internal view returns (address implementation_) {
        // Retrieve the _implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function _toInt104(uint96 input_) internal pure returns (int104 output_) {
        assembly {
            output_ := input_
        }
    }
}
