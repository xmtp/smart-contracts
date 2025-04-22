// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { GroupMessageBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract GroupMessageBroadcasterTests is Test, Utils {
    uint256 internal constant _STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes internal constant _PAUSED_KEY = "xmtp.groupMessageBroadcaster.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.groupMessageBroadcaster.migrator";
    bytes internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.groupMessageBroadcaster.minPayloadSize";
    bytes internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.groupMessageBroadcaster.maxPayloadSize";

    GroupMessageBroadcasterHarness internal _broadcaster;

    address internal _implementation;
    address internal _parameterRegistry;

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new GroupMessageBroadcasterHarness(_parameterRegistry));

        _mockParameterRegistryCall(_MAX_PAYLOAD_SIZE_KEY, _STARTING_MAX_PAYLOAD_SIZE);
        _mockParameterRegistryCall(_MIN_PAYLOAD_SIZE_KEY, _STARTING_MIN_PAYLOAD_SIZE);

        _broadcaster = GroupMessageBroadcasterHarness(address(new Proxy(_implementation)));

        _broadcaster.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistryAddress() external {
        vm.expectRevert(IPayloadBroadcaster.ZeroParameterRegistryAddress.selector);
        new GroupMessageBroadcasterHarness(address(0));
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
        assertEq(_broadcaster.parameterRegistry(), _parameterRegistry);
        assertEq(_broadcaster.minPayloadSize(), _STARTING_MIN_PAYLOAD_SIZE);
        assertEq(_broadcaster.maxPayloadSize(), _STARTING_MAX_PAYLOAD_SIZE);
        assertEq(_broadcaster.__getSequenceId(), 0);
    }

    /* ============ addMessage ============ */

    function test_addMessage_whenPaused() external {
        _broadcaster.__setPauseStatus(true);

        bytes memory message_ = _generatePayload(_broadcaster.minPayloadSize());

        vm.expectRevert(IPayloadBroadcaster.Paused.selector);

        _broadcaster.addMessage(ID, message_);
    }

    function test_addMessage_payloadTooSmall() external {
        _broadcaster.__setMinPayloadSize(100);
        _broadcaster.__setMaxPayloadSize(200);

        bytes memory message_ = _generatePayload(99);

        vm.expectRevert(abi.encodeWithSelector(IPayloadBroadcaster.InvalidPayloadSize.selector, 99, 100, 200));

        _broadcaster.addMessage(ID, message_);
    }

    function test_addMessage_payloadTooLarge() external {
        _broadcaster.__setMinPayloadSize(100);
        _broadcaster.__setMaxPayloadSize(200);

        bytes memory message_ = _generatePayload(201);

        vm.expectRevert(abi.encodeWithSelector(IPayloadBroadcaster.InvalidPayloadSize.selector, 201, 100, 200));

        _broadcaster.addMessage(ID, message_);
    }

    function test_addMessage_minPayload() external {
        _broadcaster.__setMinPayloadSize(100);
        _broadcaster.__setMaxPayloadSize(200);

        bytes memory message_ = _generatePayload(100);

        vm.expectEmit(address(_broadcaster));
        emit IGroupMessageBroadcaster.MessageSent(ID, message_, 1);

        _broadcaster.addMessage(ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    function test_addMessage_maxPayload() external {
        _broadcaster.__setMinPayloadSize(100);
        _broadcaster.__setMaxPayloadSize(200);

        bytes memory message_ = _generatePayload(200);

        vm.expectEmit(address(_broadcaster));
        emit IGroupMessageBroadcaster.MessageSent(ID, message_, 1);

        _broadcaster.addMessage(ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: ci.fuzz.runs = 1_000
    function testFuzz_addMessage(
        uint256 minPayloadSize_,
        uint256 maxPayloadSize_,
        uint256 payloadSize_,
        uint64 sequenceId_,
        bool paused_
    ) external {
        minPayloadSize_ = bound(minPayloadSize_, 1, _STARTING_MAX_PAYLOAD_SIZE);
        maxPayloadSize_ = bound(maxPayloadSize_, minPayloadSize_, _STARTING_MAX_PAYLOAD_SIZE);
        payloadSize_ = bound(payloadSize_, 1, _STARTING_MAX_PAYLOAD_SIZE);
        sequenceId_ = uint64(bound(sequenceId_, 0, type(uint64).max - 1));

        _broadcaster.__setSequenceId(sequenceId_);
        _broadcaster.__setMinPayloadSize(minPayloadSize_);
        _broadcaster.__setMaxPayloadSize(maxPayloadSize_);
        _broadcaster.__setPauseStatus(paused_);

        bytes memory message_ = _generatePayload(payloadSize_);

        bool shouldFail_ = (payloadSize_ < minPayloadSize_) || (payloadSize_ > maxPayloadSize_) || paused_;

        if (shouldFail_) {
            vm.expectRevert();
        } else {
            vm.expectEmit(address(_broadcaster));
            emit IGroupMessageBroadcaster.MessageSent(ID, message_, sequenceId_ + 1);
        }

        _broadcaster.addMessage(ID, message_);

        if (shouldFail_) return;

        assertEq(_broadcaster.__getSequenceId(), sequenceId_ + 1);
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
