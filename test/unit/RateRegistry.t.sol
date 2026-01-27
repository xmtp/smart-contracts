// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { RateRegistryHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract RateRegistryTests is Test {
    string internal constant _MESSAGE_FEE_KEY = "xmtp.rateRegistry.messageFee";
    string internal constant _STORAGE_FEE_KEY = "xmtp.rateRegistry.storageFee";
    string internal constant _CONGESTION_FEE_KEY = "xmtp.rateRegistry.congestionFee";
    string internal constant _TARGET_RATE_PER_MINUTE_KEY = "xmtp.rateRegistry.targetRatePerMinute";
    string internal constant _RATES_IN_EFFECT_AFTER_KEY = "xmtp.rateRegistry.ratesInEffectAfter";
    string internal constant _MIGRATOR_KEY = "xmtp.rateRegistry.migrator";

    RateRegistryHarness internal _registry;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");

    function setUp() external {
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
        assertEq(Utils.getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.messageFeeParameterKey(), _MESSAGE_FEE_KEY);
        assertEq(_registry.storageFeeParameterKey(), _STORAGE_FEE_KEY);
        assertEq(_registry.congestionFeeParameterKey(), _CONGESTION_FEE_KEY);
        assertEq(_registry.targetRatePerMinuteParameterKey(), _TARGET_RATE_PER_MINUTE_KEY);
        assertEq(_registry.ratesInEffectAfterParameterKey(), _RATES_IN_EFFECT_AFTER_KEY);
        assertEq(_registry.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_registry.__getAllRates().length, 0);
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_registry.version(), "1.0.0");
    }

    /* ============ contractName ============ */

    function test_contractName() external view {
        assertEq(_registry.contractName(), "RateRegistry");
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize();
    }

    /* ============ updateRates ============ */

    function test_updateRates_messageFeeOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MESSAGE_FEE_KEY,
            bytes32(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_storageFeeOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, 0);

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _STORAGE_FEE_KEY,
            bytes32(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_congestionFeeOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, 0);

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _CONGESTION_FEE_KEY,
            bytes32(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_targetRatePerMinuteOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _CONGESTION_FEE_KEY, 0);

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _TARGET_RATE_PER_MINUTE_KEY,
            bytes32(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_ratesInEffectAfterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _CONGESTION_FEE_KEY, 0);
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _TARGET_RATE_PER_MINUTE_KEY, 0);

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _RATES_IN_EFFECT_AFTER_KEY,
            bytes32(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates_noChange() external {
        _registry.__pushRates(100, 200, 300, 100 * 60, 500);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, bytes32(uint256(100)));
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, bytes32(uint256(200)));
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _CONGESTION_FEE_KEY, bytes32(uint256(300)));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _TARGET_RATE_PER_MINUTE_KEY,
            bytes32(uint256(100 * 60))
        );

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _RATES_IN_EFFECT_AFTER_KEY, bytes32(uint256(500)));

        vm.expectRevert(IRateRegistry.NoChange.selector);

        vm.prank(_parameterRegistry);
        _registry.updateRates();
    }

    function test_updateRates() external {
        uint64 messageFee_ = 100;
        uint64 storageFee_ = 200;
        uint64 congestionFee_ = 300;
        uint64 targetRatePerMinute_ = 100 * 60;
        uint64 ratesInEffectAfter_ = 1000;

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, bytes32(uint256(messageFee_)));

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, bytes32(uint256(storageFee_)));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _CONGESTION_FEE_KEY,
            bytes32(uint256(congestionFee_))
        );

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _TARGET_RATE_PER_MINUTE_KEY,
            bytes32(uint256(targetRatePerMinute_))
        );

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _RATES_IN_EFFECT_AFTER_KEY,
            bytes32(uint256(ratesInEffectAfter_))
        );

        vm.expectEmit(address(_registry));
        emit IRateRegistry.RatesUpdated(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_);

        vm.prank(_parameterRegistry);
        _registry.updateRates();

        IRateRegistry.Rates[] memory rates_ = _registry.__getAllRates();

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, messageFee_);
        assertEq(rates_[0].storageFee, storageFee_);
        assertEq(rates_[0].congestionFee, congestionFee_);
        assertEq(rates_[0].targetRatePerMinute, targetRatePerMinute_);
        assertEq(rates_[0].startTime, ratesInEffectAfter_);
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
        uint64 ratesInEffectAfter_ = 2000;

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MESSAGE_FEE_KEY, bytes32(uint256(messageFee_)));

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _STORAGE_FEE_KEY, bytes32(uint256(storageFee_)));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _CONGESTION_FEE_KEY,
            bytes32(uint256(congestionFee_))
        );

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _TARGET_RATE_PER_MINUTE_KEY,
            bytes32(uint256(targetRatePerMinute_))
        );

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _RATES_IN_EFFECT_AFTER_KEY,
            bytes32(uint256(ratesInEffectAfter_))
        );

        vm.expectEmit(address(_registry));
        emit IRateRegistry.RatesUpdated(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_);

        vm.prank(_parameterRegistry);
        _registry.updateRates();

        IRateRegistry.Rates[] memory rates_ = _registry.__getAllRates();

        assertEq(rates_.length, 5);

        assertEq(rates_[4].messageFee, messageFee_);
        assertEq(rates_[4].storageFee, storageFee_);
        assertEq(rates_[4].congestionFee, congestionFee_);
        assertEq(rates_[4].targetRatePerMinute, targetRatePerMinute_);
        assertEq(rates_[4].startTime, ratesInEffectAfter_);
    }

    /* ============ getRates ============ */

    function test_getRates_zeroCount() external {
        vm.expectRevert(IRateRegistry.ZeroCount.selector);
        _registry.getRates(0, 0);
    }

    function test_getRates_fromIndexOutOfRange() external {
        vm.expectRevert(IRateRegistry.FromIndexOutOfRange.selector);
        _registry.getRates(1, 1);
    }

    function test_getRates_endIndexOutOfRange() external {
        _registry.__pushRates(0, 0, 0, 0, 0);
        vm.expectRevert(IRateRegistry.EndIndexOutOfRange.selector);
        _registry.getRates(0, 2);
    }

    function test_getRates_subset() external {
        for (uint256 i_; i_ < 10; ++i_) {
            _registry.__pushRates(i_, i_, i_, i_, i_);
        }

        IRateRegistry.Rates[] memory rates_ = _registry.getRates(1, 4);

        assertEq(rates_.length, 4);

        for (uint256 i_; i_ < 4; ++i_) {
            assertEq(rates_[i_].messageFee, i_ + 1);
            assertEq(rates_[i_].storageFee, i_ + 1);
            assertEq(rates_[i_].congestionFee, i_ + 1);
            assertEq(rates_[i_].targetRatePerMinute, i_ + 1);
            assertEq(rates_[i_].startTime, i_ + 1);
        }
    }

    function test_getRates_entirety() external {
        for (uint256 i_; i_ < 10; ++i_) {
            _registry.__pushRates(i_, i_, i_, i_, i_);
        }

        IRateRegistry.Rates[] memory rates_ = _registry.getRates(0, 10);

        assertEq(rates_.length, 10);

        for (uint256 i_; i_ < 10; ++i_) {
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
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
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
        _registry.__pushRates(100, 200, 300, 100 * 60, 500);

        address newImplementation_ = address(new RateRegistryHarness(_parameterRegistry));
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

        assertEq(_registry.getRatesCount(), 1);

        IRateRegistry.Rates[] memory rates_ = _registry.getRates(0, 1);

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, 100);
        assertEq(rates_[0].storageFee, 200);
        assertEq(rates_[0].congestionFee, 300);
        assertEq(rates_[0].targetRatePerMinute, 100 * 60);
        assertEq(rates_[0].startTime, 500);
    }
}
