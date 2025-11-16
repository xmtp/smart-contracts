// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { IdentityUpdateBroadcasterHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract IdentityUpdateBroadcasterTests is Test {
    bytes32 internal constant _ID = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    string internal constant _PAUSED_KEY = "xmtp.identityUpdateBroadcaster.paused";
    string internal constant _MIGRATOR_KEY = "xmtp.identityUpdateBroadcaster.migrator";
    string internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.identityUpdateBroadcaster.minPayloadSize";
    string internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.identityUpdateBroadcaster.maxPayloadSize";
    string internal constant _PAYLOAD_BOOTSTRAPPER_KEY = "xmtp.identityUpdateBroadcaster.payloadBootstrapper";

    IdentityUpdateBroadcasterHarness internal _broadcaster;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _payloadBootstrapper = makeAddr("payloadBootstrapper");

    function setUp() external {
        _implementation = address(new IdentityUpdateBroadcasterHarness(_parameterRegistry));
        _broadcaster = IdentityUpdateBroadcasterHarness(address(new Proxy(_implementation)));

        _broadcaster.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IPayloadBroadcaster.ZeroParameterRegistry.selector);
        new IdentityUpdateBroadcasterHarness(address(0));
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
        assertEq(_broadcaster.payloadBootstrapperParameterKey(), _PAYLOAD_BOOTSTRAPPER_KEY);
        assertFalse(_broadcaster.paused());
        assertEq(_broadcaster.payloadBootstrapper(), address(0));
        assertEq(_broadcaster.parameterRegistry(), _parameterRegistry);
        assertEq(_broadcaster.minPayloadSize(), 0);
        assertEq(_broadcaster.maxPayloadSize(), 0);
        assertEq(_broadcaster.__getSequenceId(), 0);
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_broadcaster.version(), "0.1.0");
    }

    /* ============ addIdentityUpdate ============ */

    function test_addIdentityUpdate_whenPaused() external {
        _broadcaster.__setPauseStatus(true);

        bytes memory message_ = Utils.generatePayload(_broadcaster.minPayloadSize());

        vm.expectRevert(IPayloadBroadcaster.Paused.selector);

        _broadcaster.addIdentityUpdate(_ID, message_);
    }

    function test_addIdentityUpdate_payloadTooSmall() external {
        _broadcaster.__setMinPayloadSize(78);

        bytes memory message_ = Utils.generatePayload(77);

        vm.expectRevert(abi.encodeWithSelector(IPayloadBroadcaster.InvalidPayloadSize.selector, 77, 78, 0));

        _broadcaster.addIdentityUpdate(_ID, message_);
    }

    function test_addIdentityUpdate_payloadTooLarge() external {
        _broadcaster.__setMaxPayloadSize(4_194_304);

        bytes memory message_ = Utils.generatePayload(4_194_305);

        vm.expectRevert(
            abi.encodeWithSelector(IPayloadBroadcaster.InvalidPayloadSize.selector, 4_194_305, 0, 4_194_304)
        );

        _broadcaster.addIdentityUpdate(_ID, message_);
    }

    function test_addIdentityUpdate_minPayload() external {
        _broadcaster.__setMinPayloadSize(1);
        _broadcaster.__setMaxPayloadSize(1);

        bytes memory message_ = Utils.generatePayload(1);

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(_ID, message_, 1);

        _broadcaster.addIdentityUpdate(_ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    function test_addIdentityUpdate_maxPayload() external {
        _broadcaster.__setMaxPayloadSize(4_194_304);

        bytes memory message_ = Utils.generatePayload(4_194_304);

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(_ID, message_, 1);

        _broadcaster.addIdentityUpdate(_ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: ci.fuzz.runs = 1_000
    function testFuzz_addIdentityUpdate(
        uint256 minPayloadSize_,
        uint256 maxPayloadSize_,
        uint256 payloadSize_,
        uint64 sequenceId_,
        bool paused_
    ) external {
        minPayloadSize_ = _bound(minPayloadSize_, 1, 4_194_304);
        maxPayloadSize_ = _bound(maxPayloadSize_, minPayloadSize_, 4_194_304);
        payloadSize_ = _bound(payloadSize_, 1, 4_194_304);
        sequenceId_ = uint64(_bound(sequenceId_, 0, type(uint64).max - 1));

        _broadcaster.__setSequenceId(sequenceId_);
        _broadcaster.__setMinPayloadSize(minPayloadSize_);
        _broadcaster.__setMaxPayloadSize(maxPayloadSize_);
        _broadcaster.__setPauseStatus(paused_);

        bytes memory message_ = Utils.generatePayload(payloadSize_);

        bool shouldFail_ = (payloadSize_ < minPayloadSize_) || (payloadSize_ > maxPayloadSize_) || paused_;

        if (shouldFail_) {
            vm.expectRevert();
        } else {
            vm.expectEmit(address(_broadcaster));
            emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(_ID, message_, sequenceId_ + 1);
        }

        _broadcaster.addIdentityUpdate(_ID, message_);

        if (shouldFail_) return;

        assertEq(_broadcaster.__getSequenceId(), sequenceId_ + 1);
    }

    /* ============ bootstrapIdentityUpdates ============ */

    function test_bootstrapIdentityUpdates_whenNotPaused() external {
        _broadcaster.__setPauseStatus(false);

        vm.expectRevert(IPayloadBroadcaster.NotPaused.selector);

        _broadcaster.bootstrapIdentityUpdates(new bytes32[](0), new bytes[](0), new uint64[](0));
    }

    function test_bootstrapIdentityUpdates_notPayloadBootstrapper() external {
        _broadcaster.__setPauseStatus(true);

        vm.expectRevert(IPayloadBroadcaster.NotPayloadBootstrapper.selector);

        _broadcaster.bootstrapIdentityUpdates(new bytes32[](0), new bytes[](0), new uint64[](0));
    }

    function test_bootstrapIdentityUpdates_arrayLengthMismatch() external {
        _broadcaster.__setPauseStatus(true);
        _broadcaster.__setPayloadBootstrapper(_payloadBootstrapper);

        vm.expectRevert(IIdentityUpdateBroadcaster.ArrayLengthMismatch.selector);

        vm.prank(_payloadBootstrapper);
        _broadcaster.bootstrapIdentityUpdates(new bytes32[](1), new bytes[](0), new uint64[](1));

        vm.expectRevert(IIdentityUpdateBroadcaster.ArrayLengthMismatch.selector);

        vm.prank(_payloadBootstrapper);
        _broadcaster.bootstrapIdentityUpdates(new bytes32[](1), new bytes[](1), new uint64[](0));
    }

    function test_bootstrapIdentityUpdates_emptyArray() external {
        _broadcaster.__setPauseStatus(true);
        _broadcaster.__setPayloadBootstrapper(_payloadBootstrapper);

        vm.expectRevert(IIdentityUpdateBroadcaster.EmptyArray.selector);

        vm.prank(_payloadBootstrapper);
        _broadcaster.bootstrapIdentityUpdates(new bytes32[](0), new bytes[](0), new uint64[](0));
    }

    function test_bootstrapIdentityUpdates() external {
        _broadcaster.__setPauseStatus(true);
        _broadcaster.__setPayloadBootstrapper(_payloadBootstrapper);
        _broadcaster.__setSequenceId(5);

        bytes32[] memory inboxIds_ = new bytes32[](2);
        inboxIds_[0] = bytes32(uint256(1));
        inboxIds_[1] = bytes32(uint256(2));

        bytes[] memory identityUpdates_ = new bytes[](2);
        identityUpdates_[0] = Utils.generatePayload(1);
        identityUpdates_[1] = Utils.generatePayload(1);

        uint64[] memory sequenceIds_ = new uint64[](2);
        sequenceIds_[0] = 18;
        sequenceIds_[1] = 9;

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(inboxIds_[0], identityUpdates_[0], sequenceIds_[0]);

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(inboxIds_[1], identityUpdates_[1], sequenceIds_[1]);

        vm.prank(_payloadBootstrapper);
        _broadcaster.bootstrapIdentityUpdates(inboxIds_, identityUpdates_, sequenceIds_);

        assertEq(_broadcaster.__getSequenceId(), 18);
    }
}
