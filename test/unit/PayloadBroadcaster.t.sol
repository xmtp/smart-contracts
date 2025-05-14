// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { PayloadBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayloadBroadcasterTests is Test {
    uint256 internal constant _STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes internal constant _PAUSED_KEY = "xmtp.payloadBroadcaster.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.payloadBroadcaster.migrator";
    bytes internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.payloadBroadcaster.minPayloadSize";
    bytes internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.payloadBroadcaster.maxPayloadSize";

    PayloadBroadcasterHarness internal _broadcaster;

    address internal _implementation;
    address internal _parameterRegistry;

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new PayloadBroadcasterHarness(_parameterRegistry));

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MAX_PAYLOAD_SIZE_KEY,
            bytes32(_STARTING_MAX_PAYLOAD_SIZE)
        );

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIN_PAYLOAD_SIZE_KEY,
            bytes32(_STARTING_MIN_PAYLOAD_SIZE)
        );

        _broadcaster = PayloadBroadcasterHarness(address(new Proxy(_implementation)));

        _broadcaster.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IPayloadBroadcaster.ZeroParameterRegistry.selector);
        new PayloadBroadcasterHarness(address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _broadcaster.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_broadcaster)), _implementation);
        assertEq(_broadcaster.implementation(), _implementation);
        assertEq(keccak256(_broadcaster.minPayloadSizeParameterKey()), keccak256(_MIN_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(_broadcaster.maxPayloadSizeParameterKey()), keccak256(_MAX_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(_broadcaster.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(keccak256(_broadcaster.pausedParameterKey()), keccak256(_PAUSED_KEY));
        assertFalse(_broadcaster.paused());
        assertEq(_broadcaster.parameterRegistry(), _parameterRegistry);
        assertEq(_broadcaster.minPayloadSize(), _STARTING_MIN_PAYLOAD_SIZE);
        assertEq(_broadcaster.maxPayloadSize(), _STARTING_MAX_PAYLOAD_SIZE);
        assertEq(_broadcaster.__getSequenceId(), 0);
    }

    /* ============ updateMinPayloadSize ============ */

    function test_updateMinPayloadSize_greaterThanMax() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_noChange() external {
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(100)));

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize() external {
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MinPayloadSizeUpdated(101);

        _broadcaster.updateMinPayloadSize();

        assertEq(_broadcaster.minPayloadSize(), 101);
    }

    /* ============ updateMaxPayloadSize ============ */

    function test_updateMaxPayloadSize_lessThanMin() external {
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(99)));

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_noChange() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(100)));

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MaxPayloadSizeUpdated(101);

        _broadcaster.updateMaxPayloadSize();

        assertEq(_broadcaster.maxPayloadSize(), 101);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_noChange() external {
        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _broadcaster.__setPauseStatus(true);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _broadcaster.updatePauseStatus();

        assertTrue(_broadcaster.paused());

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _PAUSED_KEY, bytes32(0));

        _broadcaster.updatePauseStatus();

        assertFalse(_broadcaster.paused());
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _broadcaster.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                migrator_,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _broadcaster.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(uint160(1))));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _broadcaster.migrate();
    }

    function test_migrate() external {
        _broadcaster.__setMaxPayloadSize(100);
        _broadcaster.__setMinPayloadSize(50);
        _broadcaster.__setSequenceId(10);

        address newImplementation_ = address(new PayloadBroadcasterHarness(_parameterRegistry));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_broadcaster));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_broadcaster));
        emit IERC1967.Upgraded(newImplementation_);

        _broadcaster.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_broadcaster)), newImplementation_);
        assertEq(_broadcaster.parameterRegistry(), _parameterRegistry);
        assertEq(_broadcaster.maxPayloadSize(), 100);
        assertEq(_broadcaster.minPayloadSize(), 50);
        assertEq(_broadcaster.__getSequenceId(), 10);
    }
}
