// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { PayloadBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayloadBroadcasterTests is Test {
    string internal constant _PAUSED_KEY = "xmtp.payloadBroadcaster.paused";
    string internal constant _MIGRATOR_KEY = "xmtp.payloadBroadcaster.migrator";
    string internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.payloadBroadcaster.minPayloadSize";
    string internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.payloadBroadcaster.maxPayloadSize";
    string internal constant _PAYLOAD_BOOTSTRAPPER_KEY = "xmtp.payloadBroadcaster.payloadBootstrapper";

    PayloadBroadcasterHarness internal _broadcaster;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");

    function setUp() external {
        _implementation = address(new PayloadBroadcasterHarness(_parameterRegistry));
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
        assertEq(_broadcaster.minPayloadSizeParameterKey(), _MIN_PAYLOAD_SIZE_KEY);
        assertEq(_broadcaster.maxPayloadSizeParameterKey(), _MAX_PAYLOAD_SIZE_KEY);
        assertEq(_broadcaster.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_broadcaster.pausedParameterKey(), _PAUSED_KEY);
        assertFalse(_broadcaster.paused());
        assertEq(_broadcaster.payloadBootstrapper(), address(0));
        assertEq(_broadcaster.parameterRegistry(), _parameterRegistry);
        assertEq(_broadcaster.minPayloadSize(), 0);
        assertEq(_broadcaster.maxPayloadSize(), 0);
        assertEq(_broadcaster.__getSequenceId(), 0);
    }

    /* ============ updateMinPayloadSize ============ */

    function test_updateMinPayloadSize_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIN_PAYLOAD_SIZE_KEY,
            bytes32(uint256(type(uint32).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_greaterThanMax() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_lessThanAbsoluteMin() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, 0);

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_noChange() external {
        _broadcaster.__setMaxPayloadSize(100);
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(100)));

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize() external {
        _broadcaster.__setMaxPayloadSize(200);
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIN_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MinPayloadSizeUpdated(101);

        _broadcaster.updateMinPayloadSize();

        assertEq(_broadcaster.minPayloadSize(), 101);
    }

    /* ============ updateMaxPayloadSize ============ */

    function test_updateMaxPayloadSize_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MAX_PAYLOAD_SIZE_KEY,
            bytes32(uint256(type(uint32).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_lessThanMin() external {
        _broadcaster.__setMinPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(99)));

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_greaterThanAbsoluteMax() external {
        _broadcaster.__setMinPayloadSize(1);

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MAX_PAYLOAD_SIZE_KEY,
            bytes32(uint256(256 * 1024 + 1))
        );

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_noChange() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(100)));

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize() external {
        _broadcaster.__setMaxPayloadSize(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MAX_PAYLOAD_SIZE_KEY, bytes32(uint256(101)));

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MaxPayloadSizeUpdated(101);

        _broadcaster.updateMaxPayloadSize();

        assertEq(_broadcaster.maxPayloadSize(), 101);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _broadcaster.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _broadcaster.__setPauseStatus(true);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _broadcaster.updatePauseStatus();

        assertTrue(_broadcaster.paused());

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        _broadcaster.updatePauseStatus();

        assertFalse(_broadcaster.paused());
    }

    /* ============ updatePayloadBootstrapper ============ */

    function test_updatePayloadBootstrapper_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PAYLOAD_BOOTSTRAPPER_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _broadcaster.updatePayloadBootstrapper();
    }

    function test_updatePayloadBootstrapper_zeroPayloadBootstrapper() external {
        _broadcaster.__setPayloadBootstrapper(address(1));

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAYLOAD_BOOTSTRAPPER_KEY, 0);

        vm.expectRevert(IPayloadBroadcaster.ZeroPayloadBootstrapper.selector);

        _broadcaster.updatePayloadBootstrapper();
    }

    function test_updatePayloadBootstrapper_noChange() external {
        _broadcaster.__setPayloadBootstrapper(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PAYLOAD_BOOTSTRAPPER_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePayloadBootstrapper();
    }

    function test_updatePayloadBootstrapper() external {
        _broadcaster.__setPayloadBootstrapper(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PAYLOAD_BOOTSTRAPPER_KEY,
            bytes32(uint256(uint160(address(2))))
        );

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PayloadBootstrapperUpdated(address(2));

        _broadcaster.updatePayloadBootstrapper();

        assertEq(_broadcaster.payloadBootstrapper(), address(2));
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _broadcaster.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _broadcaster.migrate();
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

        _broadcaster.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(uint160(1))));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _broadcaster.migrate();
    }

    function test_migrate() external {
        _broadcaster.__setMaxPayloadSize(100);
        _broadcaster.__setMinPayloadSize(50);
        _broadcaster.__setSequenceId(10);

        address newImplementation_ = address(new PayloadBroadcasterHarness(_parameterRegistry));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
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
