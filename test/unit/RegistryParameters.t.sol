// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { RegistryParametersHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract RegistryParametersTests is Test {
    RegistryParametersHarness internal _registryParameters;

    address internal _parameterRegistry = makeAddr("parameterRegistry");

    function setUp() external {
        _registryParameters = new RegistryParametersHarness();
    }

    /* ============ setRegistryParameter ============ */

    function test_setRegistryParameter() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("set(bytes,bytes32)", bytes("key"), bytes32("value")),
            ""
        );

        _registryParameters.setRegistryParameter(_parameterRegistry, "key", "value");
    }

    /* ============ getRegistryParameters ============ */

    function test_getRegistryParameters() external {
        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = bytes("key");

        bytes32[] memory values_ = new bytes32[](1);
        values_[0] = "value";

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes[])", keys_),
            abi.encode(values_)
        );

        bytes32[] memory result_ = _registryParameters.getRegistryParameters(_parameterRegistry, keys_);
        assertEq(result_.length, 1);
        assertEq(result_[0], values_[0]);
    }

    /* ============ getRegistryParameter ============ */

    function test_getRegistryParameter() external {
        bytes memory key_ = bytes("key");
        bytes32 value_ = "value";

        Utils.expectAndMockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", key_), abi.encode(value_));

        bytes32 result_ = _registryParameters.getRegistryParameter(_parameterRegistry, key_);
        assertEq(result_, value_);
    }

    /* ============ getAddressParameter ============ */

    function test_getAddressParameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getAddressParameter(_parameterRegistry, "key");
    }

    function test_getAddressParameter() external {
        address expected_ = makeAddr("address");

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(expected_)
        );

        assertEq(_registryParameters.getAddressParameter(_parameterRegistry, "key"), expected_);
    }

    /* ============ getBoolParameter ============ */

    function test_getBoolParameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", bytes("key")), abi.encode(2));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getBoolParameter(_parameterRegistry, "key");
    }

    function test_getBoolParameter() external {
        Utils.expectAndMockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", bytes("key")), abi.encode(0));

        assertEq(_registryParameters.getBoolParameter(_parameterRegistry, "key"), false);

        Utils.expectAndMockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", bytes("key")), abi.encode(1));

        assertEq(_registryParameters.getBoolParameter(_parameterRegistry, "key"), true);
    }

    /* ============ getUint8Parameter ============ */

    function test_getUint8Parameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(uint256(type(uint8).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getUint8Parameter(_parameterRegistry, "key");
    }

    function test_getUint8Parameter() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(type(uint8).max)
        );

        assertEq(_registryParameters.getUint8Parameter(_parameterRegistry, "key"), type(uint8).max);
    }

    /* ============ getUint32Parameter ============ */

    function test_getUint32Parameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(uint256(type(uint32).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getUint32Parameter(_parameterRegistry, "key");
    }

    function test_getUint32Parameter() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(type(uint32).max)
        );

        assertEq(_registryParameters.getUint32Parameter(_parameterRegistry, "key"), type(uint32).max);
    }

    /* ============ getUint64Parameter ============ */

    function test_getUint64Parameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(uint256(type(uint64).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getUint64Parameter(_parameterRegistry, "key");
    }

    function test_getUint64Parameter() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(type(uint64).max)
        );

        assertEq(_registryParameters.getUint64Parameter(_parameterRegistry, "key"), type(uint64).max);
    }

    /* ============ getUint96Parameter ============ */

    function test_getUint96Parameter_parameterOutOfTypeBounds() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(uint256(type(uint96).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getUint96Parameter(_parameterRegistry, "key");
    }

    function test_getUint96Parameter() external {
        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", bytes("key")),
            abi.encode(type(uint96).max)
        );

        assertEq(_registryParameters.getUint96Parameter(_parameterRegistry, "key"), type(uint96).max);
    }

    /* ============ getAddressFromRawParameter ============ */

    function test_getAddressFromRawParameter_parameterOutOfTypeBounds() external {
        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _registryParameters.getAddressFromRawParameter(bytes32(uint256(type(uint160).max) + 1));
    }

    function test_getAddressFromRawParameter() external {
        address expected_ = makeAddr("address");

        assertEq(_registryParameters.getAddressFromRawParameter(bytes32(uint256(uint160(expected_)))), expected_);
    }
}
