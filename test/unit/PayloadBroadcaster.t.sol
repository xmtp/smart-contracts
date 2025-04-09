// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { PayloadBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract PayloadBroadcasterTests is Test, Utils {
    uint256 internal constant _ABSOLUTE_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _ABSOLUTE_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes internal constant _PAUSED_KEY = "xmtp.pb.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.pb.migrator";
    bytes internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.pb.minPayloadSize";
    bytes internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.pb.maxPayloadSize";

    address internal _implementation;

    PayloadBroadcasterHarness internal _broadcaster;

    address internal _registry;

    function setUp() external {
        _registry = address(new MockParameterRegistry());
        _implementation = address(new PayloadBroadcasterHarness(_registry));

        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, _ABSOLUTE_MAX_PAYLOAD_SIZE);
        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, _ABSOLUTE_MIN_PAYLOAD_SIZE);

        _broadcaster = PayloadBroadcasterHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroRegistryAddress() external {
        vm.expectRevert(IPayloadBroadcaster.ZeroRegistryAddress.selector);
        new PayloadBroadcasterHarness(address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _broadcaster.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_broadcaster)), _implementation);
        assertEq(_broadcaster.implementation(), _implementation);
        assertEq(keccak256(_broadcaster.minPayloadSizeParameterKey()), keccak256(_MIN_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(_broadcaster.maxPayloadSizeParameterKey()), keccak256(_MAX_PAYLOAD_SIZE_KEY));
        assertEq(keccak256(_broadcaster.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(keccak256(_broadcaster.pausedParameterKey()), keccak256(_PAUSED_KEY));
        assertFalse(_broadcaster.paused());
        assertEq(_broadcaster.registry(), _registry);
        assertEq(_broadcaster.minPayloadSize(), _ABSOLUTE_MIN_PAYLOAD_SIZE);
        assertEq(_broadcaster.maxPayloadSize(), _ABSOLUTE_MAX_PAYLOAD_SIZE);
        assertEq(_broadcaster.__getSequenceId(), 0);
    }

    /* ============ updateMinPayloadSize ============ */

    function test_updateMinPayloadSize_greaterThanMax() external {
        _broadcaster.__setMaxPayloadSize(100);

        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, 101);

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_lessThanOrEqualToAbsoluteMin() external {
        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, _ABSOLUTE_MIN_PAYLOAD_SIZE - 1);

        vm.expectRevert(IPayloadBroadcaster.InvalidMinPayloadSize.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize_noChange() external {
        _broadcaster.__setMinPayloadSize(100);

        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, 100);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMinPayloadSize();
    }

    function test_updateMinPayloadSize() external {
        _broadcaster.__setMinPayloadSize(100);

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, 101);

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MinPayloadSizeUpdated(101);

        _broadcaster.updateMinPayloadSize();

        assertEq(_broadcaster.minPayloadSize(), 101);
    }

    /* ============ updateMaxPayloadSize ============ */

    function test_updateMaxPayloadSize_lessThanMin() external {
        _broadcaster.__setMinPayloadSize(100);

        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, 99);

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_greaterThanOrEqualToAbsoluteMax() external {
        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, _ABSOLUTE_MAX_PAYLOAD_SIZE + 1);

        vm.expectRevert(IPayloadBroadcaster.InvalidMaxPayloadSize.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize_noChange() external {
        _broadcaster.__setMaxPayloadSize(100);

        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, 100);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updateMaxPayloadSize();
    }

    function test_updateMaxPayloadSize() external {
        _broadcaster.__setMaxPayloadSize(100);

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, 101);

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.MaxPayloadSizeUpdated(101);

        _broadcaster.updateMaxPayloadSize();

        assertEq(_broadcaster.maxPayloadSize(), 101);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_noChange() external {
        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();

        _mockRegistryCall(_PAUSED_KEY, true);

        _broadcaster.__setPauseStatus(true);

        vm.expectRevert(IPayloadBroadcaster.NoChange.selector);

        _broadcaster.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(true);

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_PAUSED_KEY, true);

        _broadcaster.updatePauseStatus();

        assertTrue(_broadcaster.paused());

        vm.expectEmit(address(_broadcaster));
        emit IPayloadBroadcaster.PauseStatusUpdated(false);

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_PAUSED_KEY, false);

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

        _mockRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _broadcaster.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockRegistryCall(_MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _broadcaster.migrate();
    }

    function test_migrate() external {
        _broadcaster.__setMaxPayloadSize(100);
        _broadcaster.__setMinPayloadSize(50);
        _broadcaster.__setSequenceId(10);

        address newImplementation_ = address(new PayloadBroadcasterHarness(_registry));
        address migrator_ = address(new MockMigrator(newImplementation_));

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_broadcaster));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_broadcaster));
        emit IERC1967.Upgraded(newImplementation_);

        _broadcaster.migrate();

        assertEq(_getImplementationFromSlot(address(_broadcaster)), newImplementation_);
        assertEq(_broadcaster.registry(), _registry);
        assertEq(_broadcaster.maxPayloadSize(), 100);
        assertEq(_broadcaster.minPayloadSize(), 50);
        assertEq(_broadcaster.__getSequenceId(), 10);
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

        vm.mockCall(_registry, abi.encodeWithSignature("get(bytes[])", keyChain_), abi.encode(value_));
    }

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
