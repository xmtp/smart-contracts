// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../lib/oz/contracts/access/IAccessControl.sol";

import { ERC1967Proxy } from "../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "../lib/oz-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { GroupMessageBroadcaster } from "../src/GroupMessageBroadcaster.sol";

import { GroupMessageBroadcasterHarness } from "./utils/Harnesses.sol";
import { Utils } from "./utils/Utils.sol";

contract GroupMessageBroadcasterTests is Test, Utils {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 constant ABSOLUTE_MIN_PAYLOAD_SIZE = 78;
    uint256 constant ABSOLUTE_MAX_PAYLOAD_SIZE = 4_194_304;

    address implementation;

    GroupMessageBroadcasterHarness broadcaster;

    address admin = makeAddr("admin");
    address unauthorized = makeAddr("unauthorized");

    function setUp() public {
        implementation = address(new GroupMessageBroadcasterHarness());

        broadcaster = GroupMessageBroadcasterHarness(
            address(
                new ERC1967Proxy(
                    implementation,
                    abi.encodeWithSelector(GroupMessageBroadcaster.initialize.selector, admin)
                )
            )
        );
    }

    /* ============ initializer ============ */

    function test_initializer_zeroAdminAddress() public {
        vm.expectRevert(GroupMessageBroadcaster.ZeroAdminAddress.selector);

        new ERC1967Proxy(
            implementation,
            abi.encodeWithSelector(GroupMessageBroadcaster.initialize.selector, address(0))
        );
    }

    /* ============ initial state ============ */

    function test_initialState() public view {
        assertEq(_getImplementationFromSlot(address(broadcaster)), implementation);
        assertEq(broadcaster.minPayloadSize(), ABSOLUTE_MIN_PAYLOAD_SIZE);
        assertEq(broadcaster.maxPayloadSize(), ABSOLUTE_MAX_PAYLOAD_SIZE);
        assertEq(broadcaster.__getSequenceId(), 0);
    }

    /* ============ addMessage ============ */

    function test_addMessage_minPayload() public {
        bytes memory message = _generatePayload(broadcaster.minPayloadSize());

        vm.expectEmit(address(broadcaster));
        emit GroupMessageBroadcaster.MessageSent(ID, message, 1);

        broadcaster.addMessage(ID, message);

        assertEq(broadcaster.__getSequenceId(), 1);
    }

    function test_addMessage_maxPayload() public {
        bytes memory message = _generatePayload(broadcaster.maxPayloadSize());

        vm.expectEmit(address(broadcaster));
        emit GroupMessageBroadcaster.MessageSent(ID, message, 1);

        broadcaster.addMessage(ID, message);

        assertEq(broadcaster.__getSequenceId(), 1);
    }

    function test_addMessage_payloadTooSmall() public {
        bytes memory message = _generatePayload(broadcaster.minPayloadSize() - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                GroupMessageBroadcaster.InvalidPayloadSize.selector,
                message.length,
                broadcaster.minPayloadSize(),
                broadcaster.maxPayloadSize()
            )
        );

        broadcaster.addMessage(ID, message);
    }

    function test_addMessage_payloadTooLarge() public {
        bytes memory message = _generatePayload(broadcaster.maxPayloadSize() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                GroupMessageBroadcaster.InvalidPayloadSize.selector,
                message.length,
                broadcaster.minPayloadSize(),
                broadcaster.maxPayloadSize()
            )
        );

        broadcaster.addMessage(ID, message);
    }

    function test_addMessage_whenPaused() public {
        broadcaster.__pause();

        bytes memory message = _generatePayload(broadcaster.minPayloadSize());

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));

        broadcaster.addMessage(ID, message);
    }

    function testFuzz_addMessage(
        uint256 minPayloadSize,
        uint256 maxPayloadSize,
        uint256 payloadSize,
        uint64 sequenceId,
        bool paused
    ) public {
        minPayloadSize = bound(minPayloadSize, ABSOLUTE_MIN_PAYLOAD_SIZE, ABSOLUTE_MAX_PAYLOAD_SIZE);
        maxPayloadSize = bound(maxPayloadSize, minPayloadSize, ABSOLUTE_MAX_PAYLOAD_SIZE);
        payloadSize = bound(payloadSize, ABSOLUTE_MIN_PAYLOAD_SIZE, ABSOLUTE_MAX_PAYLOAD_SIZE);
        sequenceId = uint64(bound(sequenceId, 0, type(uint64).max - 1));

        broadcaster.__setSequenceId(sequenceId);
        broadcaster.__setMinPayloadSize(minPayloadSize);
        broadcaster.__setMaxPayloadSize(maxPayloadSize);

        if (paused) {
            broadcaster.__pause();
        }

        bytes memory message = _generatePayload(payloadSize);

        bool shouldFail = (payloadSize < minPayloadSize) || (payloadSize > maxPayloadSize) || paused;

        if (shouldFail) {
            vm.expectRevert();
        } else {
            vm.expectEmit(address(broadcaster));
            emit GroupMessageBroadcaster.MessageSent(ID, message, sequenceId + 1);
        }

        broadcaster.addMessage(ID, message);

        if (shouldFail) return;

        assertEq(broadcaster.__getSequenceId(), sequenceId + 1);
    }

    /* ============ setMinPayloadSize ============ */

    function test_setMinPayloadSize_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        broadcaster.setMinPayloadSize(0);
    }

    function test_setMinPayloadSize_requestGreaterThanMax() public {
        broadcaster.__setMaxPayloadSize(100);

        vm.expectRevert(abi.encodeWithSelector(GroupMessageBroadcaster.InvalidMinPayloadSize.selector));

        vm.prank(admin);
        broadcaster.setMinPayloadSize(101);
    }

    function test_setMinPayloadSize_requestLessThanOrEqualToAbsoluteMin() public {
        vm.expectRevert(abi.encodeWithSelector(GroupMessageBroadcaster.InvalidMinPayloadSize.selector));

        vm.prank(admin);
        broadcaster.setMinPayloadSize(ABSOLUTE_MIN_PAYLOAD_SIZE - 1);
    }

    function test_setMinPayloadSize() public {
        uint256 initialMinSize = broadcaster.minPayloadSize();
        uint256 newMinSize = initialMinSize + 1;

        vm.expectEmit(address(broadcaster));
        emit GroupMessageBroadcaster.MinPayloadSizeUpdated(initialMinSize, newMinSize);

        vm.prank(admin);
        broadcaster.setMinPayloadSize(newMinSize);

        assertEq(broadcaster.minPayloadSize(), newMinSize);
    }

    /* ============ setMaxPayloadSize ============ */

    function test_setMaxPayloadSize_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        broadcaster.setMaxPayloadSize(0);
    }

    function test_setMaxPayloadSize_requestLessThanMin() public {
        broadcaster.__setMinPayloadSize(100);

        vm.expectRevert(abi.encodeWithSelector(GroupMessageBroadcaster.InvalidMaxPayloadSize.selector));

        vm.prank(admin);
        broadcaster.setMaxPayloadSize(99);
    }

    function test_setMaxPayloadSize_requestGreaterThanOrEqualToAbsoluteMax() public {
        vm.expectRevert(abi.encodeWithSelector(GroupMessageBroadcaster.InvalidMaxPayloadSize.selector));

        vm.prank(admin);
        broadcaster.setMaxPayloadSize(ABSOLUTE_MAX_PAYLOAD_SIZE + 1);
    }

    function test_setMaxPayloadSize() public {
        uint256 initialMaxSize = broadcaster.maxPayloadSize();
        uint256 newMaxSize = initialMaxSize - 1;

        vm.expectEmit(address(broadcaster));
        emit GroupMessageBroadcaster.MaxPayloadSizeUpdated(initialMaxSize, newMaxSize);

        vm.prank(admin);
        broadcaster.setMaxPayloadSize(newMaxSize);

        assertEq(broadcaster.maxPayloadSize(), newMaxSize);
    }

    /* ============ initialize ============ */

    function test_invalid_reinitialization() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        broadcaster.initialize(admin);
    }

    /* ============ pause ============ */

    function test_pause() public {
        vm.expectEmit(address(broadcaster));
        emit PausableUpgradeable.Paused(admin);

        vm.prank(admin);
        broadcaster.pause();

        assertTrue(broadcaster.paused());
    }

    function test_pause_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        broadcaster.pause();
    }

    function test_pause_whenPaused() public {
        broadcaster.__pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(admin);
        broadcaster.pause();
    }

    /* ============ unpause ============ */

    function test_unpause() public {
        broadcaster.__pause();

        vm.expectEmit(address(broadcaster));
        emit PausableUpgradeable.Unpaused(admin);

        vm.prank(admin);
        broadcaster.unpause();

        assertFalse(broadcaster.paused());
    }

    function test_unpause_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        broadcaster.unpause();
    }

    function test_unpause_whenNotPaused() public {
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);

        vm.prank(admin);
        broadcaster.unpause();
    }

    /* ============ upgradeToAndCall ============ */

    function test_upgradeToAndCall_notAdmin() public {
        // Unauthorized upgrade attempts should revert.
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        broadcaster.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall_zeroImplementationAddress() public {
        vm.expectRevert(GroupMessageBroadcaster.ZeroImplementationAddress.selector);

        vm.prank(admin);
        broadcaster.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall() public {
        broadcaster.__setMaxPayloadSize(100);
        broadcaster.__setMinPayloadSize(50);
        broadcaster.__setSequenceId(10);

        address newImplementation = address(new GroupMessageBroadcasterHarness());

        // Authorized upgrade should succeed and emit UpgradeAuthorized event.
        vm.expectEmit(address(broadcaster));
        emit GroupMessageBroadcaster.UpgradeAuthorized(admin, newImplementation);

        vm.prank(admin);
        broadcaster.upgradeToAndCall(newImplementation, "");

        assertEq(_getImplementationFromSlot(address(broadcaster)), newImplementation);
        assertEq(broadcaster.maxPayloadSize(), 100);
        assertEq(broadcaster.minPayloadSize(), 50);
        assertEq(broadcaster.__getSequenceId(), 10);
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy) internal view returns (address) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
