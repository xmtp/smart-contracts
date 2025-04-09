// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { IdentityUpdateBroadcasterHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract IdentityUpdateBroadcasterTests is Test, Utils {
    uint256 internal constant _ABSOLUTE_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _ABSOLUTE_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes internal constant _PAUSED_KEY = "xmtp.iub.paused";
    bytes internal constant _MIGRATOR_KEY = "xmtp.iub.migrator";
    bytes internal constant _MIN_PAYLOAD_SIZE_KEY = "xmtp.iub.minPayloadSize";
    bytes internal constant _MAX_PAYLOAD_SIZE_KEY = "xmtp.iub.maxPayloadSize";

    address internal _implementation;

    IdentityUpdateBroadcasterHarness internal _broadcaster;

    address internal _registry;

    function setUp() external {
        _registry = address(new MockParameterRegistry());
        _implementation = address(new IdentityUpdateBroadcasterHarness(_registry));

        _mockRegistryCall(_MAX_PAYLOAD_SIZE_KEY, _ABSOLUTE_MAX_PAYLOAD_SIZE);
        _mockRegistryCall(_MIN_PAYLOAD_SIZE_KEY, _ABSOLUTE_MIN_PAYLOAD_SIZE);

        _broadcaster = IdentityUpdateBroadcasterHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector)))
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

    /* ============ addIdentityUpdate ============ */

    function test_addIdentityUpdate_minPayload() external {
        bytes memory message_ = _generatePayload(_broadcaster.minPayloadSize());

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message_, 1);

        _broadcaster.addIdentityUpdate(ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    function test_addIdentityUpdate_maxPayload() external {
        bytes memory message_ = _generatePayload(_broadcaster.maxPayloadSize());

        vm.expectEmit(address(_broadcaster));
        emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message_, 1);

        _broadcaster.addIdentityUpdate(ID, message_);

        assertEq(_broadcaster.__getSequenceId(), 1);
    }

    function test_addIdentityUpdate_payloadTooSmall() external {
        bytes memory message_ = _generatePayload(_broadcaster.minPayloadSize() - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPayloadBroadcaster.InvalidPayloadSize.selector,
                message_.length,
                _broadcaster.minPayloadSize(),
                _broadcaster.maxPayloadSize()
            )
        );

        _broadcaster.addIdentityUpdate(ID, message_);
    }

    function test_addIdentityUpdate_payloadTooLarge() external {
        bytes memory message_ = _generatePayload(_broadcaster.maxPayloadSize() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPayloadBroadcaster.InvalidPayloadSize.selector,
                message_.length,
                _broadcaster.minPayloadSize(),
                _broadcaster.maxPayloadSize()
            )
        );

        _broadcaster.addIdentityUpdate(ID, message_);
    }

    function test_addIdentityUpdate_whenPaused() external {
        _broadcaster.__setPauseStatus(true);

        bytes memory message_ = _generatePayload(_broadcaster.minPayloadSize());

        vm.expectRevert(IPayloadBroadcaster.Paused.selector);

        _broadcaster.addIdentityUpdate(ID, message_);
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
        minPayloadSize_ = bound(minPayloadSize_, _ABSOLUTE_MIN_PAYLOAD_SIZE, _ABSOLUTE_MAX_PAYLOAD_SIZE);
        maxPayloadSize_ = bound(maxPayloadSize_, minPayloadSize_, _ABSOLUTE_MAX_PAYLOAD_SIZE);
        payloadSize_ = bound(payloadSize_, _ABSOLUTE_MIN_PAYLOAD_SIZE, _ABSOLUTE_MAX_PAYLOAD_SIZE);
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
            emit IIdentityUpdateBroadcaster.IdentityUpdateCreated(ID, message_, sequenceId_ + 1);
        }

        _broadcaster.addIdentityUpdate(ID, message_);

        if (shouldFail_) return;

        assertEq(_broadcaster.__getSequenceId(), sequenceId_ + 1);
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
