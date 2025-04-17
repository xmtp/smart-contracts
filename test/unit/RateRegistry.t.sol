// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { RateRegistryHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract RateRegistryTests is Test, Utils {
    bytes internal constant _MESSAGE_FEE_KEY = "xmtp.rateRegistry.messageFee";
    bytes internal constant _STORAGE_FEE_KEY = "xmtp.rateRegistry.storageFee";
    bytes internal constant _CONGESTION_FEE_KEY = "xmtp.rateRegistry.congestionFee";
    bytes internal constant _TARGET_RATE_PER_MINUTE_KEY = "xmtp.rateRegistry.targetRatePerMinute";
    bytes internal constant _MIGRATOR_KEY = "xmtp.rateRegistry.migrator";

    uint256 internal constant _PAGE_SIZE = 50;

    RateRegistryHarness internal _registry;

    address internal _implementation;
    address internal _parameterRegistry;

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new RateRegistryHarness(_parameterRegistry));

        _registry = RateRegistryHarness(address(new Proxy(_implementation)));

        _registry.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IRateRegistry.ZeroParameterRegistry.selector);

        new RateRegistryHarness(address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.PAGE_SIZE(), _PAGE_SIZE);
        assertEq(_registry.messageFeeParameterKey(), _MESSAGE_FEE_KEY);
        assertEq(_registry.storageFeeParameterKey(), _STORAGE_FEE_KEY);
        assertEq(_registry.congestionFeeParameterKey(), _CONGESTION_FEE_KEY);
        assertEq(_registry.targetRatePerMinuteParameterKey(), _TARGET_RATE_PER_MINUTE_KEY);
        assertEq(_registry.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_registry.__getAllRates().length, 0);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize();
    }

    /* ============ updateRates ============ */

    function test_updateRates_noChange() external {
        _registry.__pushRates(100, 200, 300, 100 * 60, 0);

        _mockParameterRegistryCall(_MESSAGE_FEE_KEY, 100);
        _mockParameterRegistryCall(_STORAGE_FEE_KEY, 200);
        _mockParameterRegistryCall(_CONGESTION_FEE_KEY, 300);
        _mockParameterRegistryCall(_TARGET_RATE_PER_MINUTE_KEY, 100 * 60);

        vm.expectRevert(IRateRegistry.NoChange.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_first() external {
        uint64 messageFee_ = 100;
        uint64 storageFee_ = 200;
        uint64 congestionFee_ = 300;
        uint64 targetRatePerMinute_ = 100 * 60;

        _mockParameterRegistryCall(_MESSAGE_FEE_KEY, messageFee_);
        _mockParameterRegistryCall(_STORAGE_FEE_KEY, storageFee_);
        _mockParameterRegistryCall(_CONGESTION_FEE_KEY, congestionFee_);
        _mockParameterRegistryCall(_TARGET_RATE_PER_MINUTE_KEY, targetRatePerMinute_);

        vm.expectEmit(address(_registry));
        emit IRateRegistry.RatesUpdated(
            messageFee_,
            storageFee_,
            congestionFee_,
            targetRatePerMinute_,
            uint64(vm.getBlockTimestamp())
        );

        vm.prank(_parameterRegistry);
        _registry.updateRates();

        IRateRegistry.Rates[] memory rates_ = _registry.__getAllRates();

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, messageFee_);
        assertEq(rates_[0].storageFee, storageFee_);
        assertEq(rates_[0].congestionFee, congestionFee_);
        assertEq(rates_[0].targetRatePerMinute, targetRatePerMinute_);
        assertEq(rates_[0].startTime, uint64(vm.getBlockTimestamp()));
    }

    function test_addRates_nth() external {
        _registry.__pushRates(0, 0, 0, 0, 0);
        _registry.__pushRates(0, 0, 0, 0, 0);
        _registry.__pushRates(0, 0, 0, 0, 0);
        _registry.__pushRates(0, 0, 0, 0, 0);

        uint64 messageFee_ = 100;
        uint64 storageFee_ = 200;
        uint64 congestionFee_ = 300;
        uint64 targetRatePerMinute_ = 100 * 60;

        _mockParameterRegistryCall(_MESSAGE_FEE_KEY, messageFee_);
        _mockParameterRegistryCall(_STORAGE_FEE_KEY, storageFee_);
        _mockParameterRegistryCall(_CONGESTION_FEE_KEY, congestionFee_);
        _mockParameterRegistryCall(_TARGET_RATE_PER_MINUTE_KEY, targetRatePerMinute_);

        vm.expectEmit(address(_registry));
        emit IRateRegistry.RatesUpdated(
            messageFee_,
            storageFee_,
            congestionFee_,
            targetRatePerMinute_,
            uint64(vm.getBlockTimestamp())
        );

        vm.prank(_parameterRegistry);
        _registry.updateRates();

        IRateRegistry.Rates[] memory rates_ = _registry.__getAllRates();

        assertEq(rates_.length, 5);

        assertEq(rates_[4].messageFee, messageFee_);
        assertEq(rates_[4].storageFee, storageFee_);
        assertEq(rates_[4].congestionFee, congestionFee_);
        assertEq(rates_[4].targetRatePerMinute, targetRatePerMinute_);
        assertEq(rates_[4].startTime, vm.getBlockTimestamp());
    }

    /* ============ getRates ============ */

    function test_getRates_fromIndexOutOfRange() external {
        vm.expectRevert(IRateRegistry.FromIndexOutOfRange.selector);
        _registry.getRates(1);
    }

    function test_getRates_emptyArray() external view {
        (IRateRegistry.Rates[] memory rates_, bool hasMore_) = _registry.getRates(0);

        assertEq(rates_.length, 0);
        assertFalse(hasMore_);
    }

    function test_getRates_withinPageSize() external {
        for (uint256 i_; i_ < 3 * _PAGE_SIZE; ++i_) {
            _registry.__pushRates(i_, i_, i_, i_, i_);
        }

        (IRateRegistry.Rates[] memory rates_, bool hasMore_) = _registry.getRates((3 * _PAGE_SIZE) - 10);

        assertEq(rates_.length, 10);
        assertFalse(hasMore_);

        for (uint256 i_; i_ < rates_.length; ++i_) {
            assertEq(rates_[i_].messageFee, i_ + (3 * _PAGE_SIZE) - 10);
            assertEq(rates_[i_].storageFee, i_ + (3 * _PAGE_SIZE) - 10);
            assertEq(rates_[i_].congestionFee, i_ + (3 * _PAGE_SIZE) - 10);
            assertEq(rates_[i_].startTime, i_ + (3 * _PAGE_SIZE) - 10);
        }
    }

    function test_getRates_pagination() external {
        for (uint256 i_; i_ < 3 * _PAGE_SIZE; ++i_) {
            _registry.__pushRates(i_, i_, i_, i_, i_);
        }

        (IRateRegistry.Rates[] memory rates_, bool hasMore_) = _registry.getRates(0);

        assertEq(rates_.length, _PAGE_SIZE);
        assertTrue(hasMore_);

        for (uint256 i_; i_ < rates_.length; ++i_) {
            assertEq(rates_[i_].messageFee, i_);
            assertEq(rates_[i_].storageFee, i_);
            assertEq(rates_[i_].congestionFee, i_);
            assertEq(rates_[i_].targetRatePerMinute, i_);
            assertEq(rates_[i_].startTime, i_);
        }
    }

    /* ============ getRatesCount ============ */

    function test_getRatesCount() external {
        assertEq(_registry.getRatesCount(), 0);

        for (uint256 i_ = 1; i_ <= 1000; ++i_) {
            _registry.__pushRates(0, 0, 0, 0, 0);
            assertEq(_registry.getRatesCount(), i_);
        }
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
                migrator_,
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
        _registry.__pushRates(100, 200, 300, 100 * 60, 500);

        address newImplementation_ = address(new RateRegistryHarness(_parameterRegistry));
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

        (IRateRegistry.Rates[] memory rates_, bool hasMore_) = _registry.getRates(0);

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, 100);
        assertEq(rates_[0].storageFee, 200);
        assertEq(rates_[0].congestionFee, 300);
        assertEq(rates_[0].targetRatePerMinute, 100 * 60);
        assertEq(rates_[0].startTime, 500);

        assertFalse(hasMore_);
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
}
