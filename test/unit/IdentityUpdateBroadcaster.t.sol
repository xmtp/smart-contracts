// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/interfaces/IERC1967.sol";
import { IIdentityUpdateBroadcaster } from "../../src/interfaces/IIdentityUpdateBroadcaster.sol";
import { IMigratable } from "../../src/interfaces/IMigratable.sol";
import { IPayloadBroadcaster } from "../../src/interfaces/IPayloadBroadcaster.sol";

import { IdentityUpdateBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract IdentityUpdateBroadcasterTests is Test, Utils {
    uint256 constant ABSOLUTE_MIN_PAYLOAD_SIZE = 78;
    uint256 constant ABSOLUTE_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes constant PAUSED_KEY = "xmtp.iub.paused";
    bytes constant MIGRATOR_KEY = "xmtp.iub.migrator";
    bytes constant MIN_PAYLOAD_SIZE_KEY = "xmtp.iub.minPayloadSize";
    bytes constant MAX_PAYLOAD_SIZE_KEY = "xmtp.iub.maxPayloadSize";

    address implementation;

    IdentityUpdateBroadcasterHarness broadcaster;

    address registry;
    address unauthorized = makeAddr("unauthorized");

    function setUp() external {
        registry = address(new MockParameterRegistry());
        implementation = address(new IdentityUpdateBroadcasterHarness(registry));

        _mockRegistryCall(MAX_PAYLOAD_SIZE_KEY, ABSOLUTE_MAX_PAYLOAD_SIZE);
        _mockRegistryCall(MIN_PAYLOAD_SIZE_KEY, ABSOLUTE_MIN_PAYLOAD_SIZE);

        broadcaster = IdentityUpdateBroadcasterHarness(
            address(new ERC1967Proxy(implementation, abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroRegistryAddress() external {
        vm.expectRevert(IPayloadBroadcaster.ZeroRegistryAddress.selector);

        new IdentityUpdateBroadcasterHarness(address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        broadcaster.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(broadcaster)), implementation);
        assertEq(broadcaster.implementation(), implementation);
        assertEq(keccak256(broadcaster.minPayloadSizeParameterKey()), keccak256(MIN_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(broadcaster.maxPayloadSizeParameterKey()), keccak256(MAX_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(broadcaster.migratorParameterKey()), keccak256(MIGRATOR_KEY));
        assertEq(keccak256(broadcaster.pausedParameterKey()), keccak256(PAUSED_KEY));
        assertFalse(broadcaster.paused());
        assertEq(broadcaster.registry(), registry);
        assertEq(broadcaster.minPayloadSize(), ABSOLUTE_MIN_PAYLOAD_SIZE);
        assertEq(broadcaster.maxPayloadSize(), ABSOLUTE_MAX_PAYLOAD_SIZE);
        assertEq(broadcaster.__getSequenceId(), 0);
    }

    /* ============ addIdentityUpdate ============ */

    function test_addIdentityUpdate_minPayload() external {
        bytes memory message = _generatePayload(broadcaster.minPayloadSize());

        vm.expectEmit(address(broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message, 1);

        broadcaster.addIdentityUpdate(ID, message);

        assertEq(broadcaster.__getSequenceId(), 1);
    }

    function test_addIdentityUpdate_maxPayload() external {
        bytes memory message = _generatePayload(broadcaster.maxPayloadSize());

        vm.expectEmit(address(broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message, 1);

        broadcaster.addIdentityUpdate(ID, message);

        assertEq(broadcaster.__getSequenceId(), 1);
    }

    function test_addIdentityUpdate_payloadTooSmall() external {
        bytes memory message = _generatePayload(broadcaster.minPayloadSize() - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPayloadBroadcaster.InvalidPayloadSize.selector,
                message.length,
                broadcaster.minPayloadSize(),
                broadcaster.maxPayloadSize()
            )
        );

        broadcaster.addIdentityUpdate(ID, message);
    }

    function test_addIdentityUpdate_payloadTooLarge() external {
        bytes memory message = _generatePayload(broadcaster.maxPayloadSize() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPayloadBroadcaster.InvalidPayloadSize.selector,
                message.length,
                broadcaster.minPayloadSize(),
                broadcaster.maxPayloadSize()
            )
        );

        broadcaster.addIdentityUpdate(ID, message);
    }

    function test_addIdentityUpdate_whenPaused() external {
        broadcaster.__setPauseStatus(true);

        bytes memory message = _generatePayload(broadcaster.minPayloadSize());

        vm.expectRevert(IPayloadBroadcaster.Paused.selector);

        broadcaster.addIdentityUpdate(ID, message);
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: ci.fuzz.runs = 1_000
    function testFuzz_addIdentityUpdate(
        uint256 minPayloadSize,
        uint256 maxPayloadSize,
        uint256 payloadSize,
        uint64 sequenceId,
        bool paused
    ) external {
        minPayloadSize = bound(minPayloadSize, ABSOLUTE_MIN_PAYLOAD_SIZE, ABSOLUTE_MAX_PAYLOAD_SIZE);
        maxPayloadSize = bound(maxPayloadSize, minPayloadSize, ABSOLUTE_MAX_PAYLOAD_SIZE);
        payloadSize = bound(payloadSize, ABSOLUTE_MIN_PAYLOAD_SIZE, ABSOLUTE_MAX_PAYLOAD_SIZE);
        sequenceId = uint64(bound(sequenceId, 0, type(uint64).max - 1));

        broadcaster.__setSequenceId(sequenceId);
        broadcaster.__setMinPayloadSize(minPayloadSize);
        broadcaster.__setMaxPayloadSize(maxPayloadSize);
        broadcaster.__setPauseStatus(paused);

        bytes memory message = _generatePayload(payloadSize);

        bool shouldFail = (payloadSize < minPayloadSize) || (payloadSize > maxPayloadSize) || paused;

        if (shouldFail) {
            vm.expectRevert();
        } else {
            vm.expectEmit(address(broadcaster));
            emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message, sequenceId + 1);
        }

        broadcaster.addIdentityUpdate(ID, message);

        if (shouldFail) return;

        assertEq(broadcaster.__getSequenceId(), sequenceId + 1);
    }

    /* ============ updateMinPayloadSize ============ */

    function test_updateMinPayloadSize_greaterThanMax() external {
        broadcaster.__setMaxPayloadSize(100);

        _mockRegistryCall(MIN_PAYLOAD_SIZE_KEY, 101);

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_lessThanOrEqualToAbsoluteMin() external {
        _mockRegistryCall(MIN_PAYLOAD_SIZE_KEY, ABSOLUTE_MIN_PAYLOAD_SIZE - 1);

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_noChange() external {
        broadcaster.__setMinPayloadSize(100);

        _mockRegistryCall(MIN_PAYLOAD_SIZE_KEY, 100);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize() external {
        broadcaster.__setMinPayloadSize(100);

        _mockRegistryCall(MIN_PAYLOAD_SIZE_KEY, 101);

        vm.expectEmit(address(broadcaster));
        emit IPayloadBroadcaster.MinPayloadSizeUpdated(101);

        broadcaster.updateMinPayloadSize();

        assertEq(broadcaster.minPayloadSize(), 101);
    }

    /* ============ updateMaxPayloadSize ============ */

    function test_updateMaxPayloadSize_lessThanMin() external {
        broadcaster.__setMinPayloadSize(100);

        _mockRegistryCall(MAX_PAYLOAD_SIZE_KEY, 99);

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_greaterThanOrEqualToAbsoluteMax() external {
        _mockRegistryCall(MAX_PAYLOAD_SIZE_KEY, ABSOLUTE_MAX_PAYLOAD_SIZE + 1);

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_noChange() external {
        broadcaster.__setMaxPayloadSize(100);

        _mockRegistryCall(MAX_PAYLOAD_SIZE_KEY, 100);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize() external {
        broadcaster.__setMaxPayloadSize(100);

        _mockRegistryCall(MAX_PAYLOAD_SIZE_KEY, 101);

        vm.expectEmit(address(broadcaster));
        emit IPayloadBroadcaster.MaxPayloadSizeUpdated(101);

        broadcaster.updateMaxPayloadSize();

        assertEq(broadcaster.maxPayloadSize(), 101);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_noChange() external {
        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        broadcaster.updatePauseStatus();

        _mockRegistryCall(PAUSED_KEY, true);

        broadcaster.__setPauseStatus(true);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        broadcaster.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(true);

        _mockRegistryCall(PAUSED_KEY, true);

        broadcaster.updatePauseStatus();

        assertTrue(broadcaster.paused());

        vm.expectEmit(address(broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(false);

        _mockRegistryCall(PAUSED_KEY, false);

        broadcaster.updatePauseStatus();

        assertFalse(broadcaster.paused());
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        broadcaster.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator = address(new MockFailingMigrator());

        _mockRegistryCall(MIGRATOR_KEY, migrator);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        broadcaster.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockRegistryCall(MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        broadcaster.migrate();
    }

    function test_migrate() external {
        broadcaster.__setMaxPayloadSize(100);
        broadcaster.__setMinPayloadSize(50);
        broadcaster.__setSequenceId(10);

        address newImplementation = address(new IdentityUpdateBroadcasterHarness(registry));
        address migrator = address(new MockMigrator(newImplementation));

        _mockRegistryCall(MIGRATOR_KEY, migrator);

        vm.expectEmit(address(broadcaster));
        emit IMigratable.Migrated(migrator);

        vm.expectEmit(address(broadcaster));
        emit IERC1967.Upgraded(newImplementation);

        broadcaster.migrate();

        assertEq(_getImplementationFromSlot(address(broadcaster)), newImplementation);
        assertEq(broadcaster.registry(), registry);
        assertEq(broadcaster.maxPayloadSize(), 100);
        assertEq(broadcaster.minPayloadSize(), 50);
        assertEq(broadcaster.__getSequenceId(), 10);
    }

    /* ============ helper functions ============ */

    function _mockRegistryCall(bytes memory key_, address value_) internal {
        _mockRegistryCall(key_, bytes32(uint256(uint160(value_))));
    }

    function _mockRegistryCall(bytes memory key_, bool value_) internal {
        _mockRegistryCall(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function _mockRegistryCall(bytes memory key_, uint256 value_) internal {
        _mockRegistryCall(key_, bytes32(value_));
    }

    function _mockRegistryCall(bytes memory key_, bytes32 value_) internal {
        bytes[] memory keyChain_ = new bytes[](1);
        keyChain_[0] = key_;

        vm.mockCall(
            registry,
            abi.encodeWithSelector(MockParameterRegistry.get.selector, keyChain_),
            abi.encode(value_)
        );
    }

    function _getImplementationFromSlot(address proxy) internal view returns (address) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
