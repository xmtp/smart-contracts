// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { Factory } from "../../src/any-chain/Factory.sol";
import { Proxy } from "../../src/any-chain/Proxy.sol";

contract Foo {
    uint256 public constant CONSTANT_VALUE = 123;

    uint256 public immutable immutableValue;

    uint256 public value;

    constructor(uint256 immutableValue_, uint256 value_) {
        immutableValue = immutableValue_;
        value = value_;
    }

    function initialize(uint256 value_) external {
        value = value_;
    }
}

contract FactoryTests is Test {
    Factory internal _factory;

    address internal _parameterRegistry = makeAddr("parameterRegistry");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        address implementation_ = address(new Factory(_parameterRegistry));

        vm.prank(_alice);
        _factory = Factory(address(new Proxy(implementation_)));

        _factory.initialize();
    }

    function test_deployImplementation() external {
        bytes memory initCode1_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(789)));

        address expectedImplementation1_ = _factory.computeImplementationAddress(initCode1_);

        address foo1_ = _factory.deployImplementation(initCode1_);

        assertEq(foo1_, expectedImplementation1_);
        assertEq(Foo(foo1_).CONSTANT_VALUE(), 123);
        assertEq(Foo(foo1_).immutableValue(), 456);
        assertEq(Foo(foo1_).value(), 789);

        bytes32 codehash1_ = address(foo1_).codehash;

        bytes memory initCode2_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(987)));

        address expectedImplementation2_ = _factory.computeImplementationAddress(initCode2_);

        address foo2_ = _factory.deployImplementation(initCode2_);

        assertEq(foo2_, expectedImplementation2_);
        assertEq(Foo(foo2_).CONSTANT_VALUE(), 123);
        assertEq(Foo(foo2_).immutableValue(), 456);
        assertEq(Foo(foo2_).value(), 987);

        // Same codehash as `foo1_` since the runtime code (which includes immutables) is the same.
        assertEq(address(foo2_).codehash, codehash1_);

        bytes memory initCode3_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(654), uint256(789)));

        address expectedImplementation3_ = _factory.computeImplementationAddress(initCode3_);

        address foo3_ = _factory.deployImplementation(initCode3_);

        assertEq(foo3_, expectedImplementation3_);
        assertEq(Foo(foo3_).CONSTANT_VALUE(), 123);
        assertEq(Foo(foo3_).immutableValue(), 654);
        assertEq(Foo(foo3_).value(), 789);

        // Different codehash since the runtime code (which includes immutables) is the different.
        assertNotEq(address(foo3_).codehash, codehash1_);

        // Cannot deploy the same bytecode again, since the salt is deterministic based the bytecode.
        vm.expectRevert(abi.encodeWithSelector(IFactory.DeployFailed.selector));
        _factory.deployImplementation(initCode3_);
    }

    function test_deployProxy() external {
        // NOTE: The `111` of `value` is irrelevant since the proxy does not see the implementation's state.
        bytes memory initCode1_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(111)));
        address implementation1_ = _factory.deployImplementation(initCode1_);

        // NOTE: The `222` of `value` is irrelevant since the proxy does not see the implementation's state.
        bytes memory initCode2_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(222)));
        address implementation2_ = _factory.deployImplementation(initCode2_);

        address expectedProxy1_ = _factory.computeProxyAddress(_alice, 0);

        vm.prank(_alice);
        address proxy_ = _factory.deployProxy(
            implementation1_,
            bytes32(uint256(0)),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(789))
        );

        assertEq(proxy_, expectedProxy1_);
        assertEq(Foo(proxy_).CONSTANT_VALUE(), 123);
        assertEq(Foo(proxy_).immutableValue(), 456);
        assertEq(Foo(proxy_).value(), 789);

        // This demonstrates that the proxy address is deterministic based on only the caller and the salt.
        address expectedProxy2_ = _factory.computeProxyAddress(_alice, bytes32(uint256(1)));

        vm.prank(_alice);
        address proxy2_ = _factory.deployProxy(
            implementation1_,
            bytes32(uint256(1)),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(789))
        );

        assertEq(proxy2_, expectedProxy2_);
        assertEq(Foo(proxy2_).CONSTANT_VALUE(), 123);
        assertEq(Foo(proxy2_).immutableValue(), 456);
        assertEq(Foo(proxy2_).value(), 789);

        // This demonstrates that the proxy address has no bearing on the arguments to `Foo.initialize`.
        address expectedProxy3_ = _factory.computeProxyAddress(_alice, bytes32(uint256(2)));

        vm.prank(_alice);
        address proxy3_ = _factory.deployProxy(
            implementation1_,
            bytes32(uint256(2)),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(987))
        );

        assertEq(proxy3_, expectedProxy3_);
        assertEq(Foo(proxy3_).CONSTANT_VALUE(), 123);
        assertEq(Foo(proxy3_).immutableValue(), 456);
        assertEq(Foo(proxy3_).value(), 987);

        // This demonstrates that a caller cannot deploy two proxies with the same salt.
        vm.expectRevert(abi.encodeWithSelector(IFactory.DeployFailed.selector));

        vm.prank(_alice);
        _factory.deployProxy(
            implementation2_,
            bytes32(uint256(0)),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(789))
        );

        // This demonstrates that a different caller can deploy a proxy with the same salt as another caller.
        address expectedProxy4_ = _factory.computeProxyAddress(_bob, bytes32(uint256(0)));

        vm.prank(_bob);
        address proxy4_ = _factory.deployProxy(
            implementation1_,
            bytes32(uint256(0)),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(789))
        );

        assertEq(proxy4_, expectedProxy4_);
        assertEq(Foo(proxy4_).CONSTANT_VALUE(), 123);
        assertEq(Foo(proxy4_).immutableValue(), 456);
        assertEq(Foo(proxy4_).value(), 789);
    }
}
