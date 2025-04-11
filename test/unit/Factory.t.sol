// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IInitializable } from "../../src/any-chain/interfaces/IInitializable.sol";

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

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        _factory = new Factory();
    }

    /* ============ constructor ============ */

    function test_constructor_xxx() external {
        address expectedFactory_ = vm.computeCreateAddress(_alice, 0);
        address expectedInitializableImplementation_ = vm.computeCreateAddress(expectedFactory_, 1);

        vm.expectEmit(expectedFactory_);
        emit IFactory.InitializableImplementationDeployed(expectedInitializableImplementation_);

        vm.prank(_alice);
        Factory factory_ = new Factory();

        assertEq(address(factory_), expectedFactory_);
        assertEq(factory_.initializableImplementation(), expectedInitializableImplementation_);
    }

    /* ============ deployImplementation ============ */

    function test_deployImplementation_emptyBytecode() external {
        vm.expectRevert(IFactory.EmptyBytecode.selector);
        _factory.deployImplementation("");
    }

    function test_deployImplementation_deployFailed() external {
        bytes memory initCode_ = hex"ff11ff";

        vm.expectRevert(IFactory.DeployFailed.selector);
        _factory.deployImplementation(initCode_);
    }

    function test_deployImplementation() external {
        bytes memory initCode_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(789)));

        address expectedImplementation_ = vm.computeCreate2Address(
            keccak256(initCode_),
            keccak256(initCode_),
            address(_factory)
        );

        vm.expectEmit(address(_factory));
        emit IFactory.ImplementationDeployed(expectedImplementation_);

        address foo_ = _factory.deployImplementation(initCode_);

        assertEq(foo_, expectedImplementation_);
        assertEq(Foo(foo_).CONSTANT_VALUE(), 123);
        assertEq(Foo(foo_).immutableValue(), 456);
        assertEq(Foo(foo_).value(), 789);
    }

    /* ============ deployProxy ============ */

    function test_deployProxy_deployFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));

        _factory.deployProxy(address(foo_), bytes32(0), "");

        vm.expectRevert(IFactory.DeployFailed.selector);
        _factory.deployProxy(address(foo_), bytes32(0), "");
    }

    function test_deployProxy_initializationFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));

        vm.mockCallRevert(
            _factory.initializableImplementation(),
            abi.encodeWithSelector(IInitializable.initialize.selector, foo_, bytes("")),
            ""
        );

        vm.expectRevert();

        _factory.deployProxy(address(foo_), bytes32(0), "");
    }

    function test_deployProxy() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));

        bytes32 initCodeHash_ = keccak256(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(_factory.initializableImplementation()))
        );

        bytes memory initializeCallData_ = abi.encodeWithSelector(Foo.initialize.selector, uint256(123));

        address expectedProxy_ = vm.computeCreate2Address(
            keccak256(abi.encode(_alice, bytes32(0))),
            initCodeHash_,
            address(_factory)
        );

        vm.expectEmit(address(_factory));
        emit IFactory.ProxyDeployed(expectedProxy_, foo_, _alice, bytes32(0), initializeCallData_);

        vm.prank(_alice);
        address proxy_ = _factory.deployProxy(foo_, bytes32(0), initializeCallData_);

        assertEq(proxy_, expectedProxy_);
    }

    /* ============ computeImplementationAddress ============ */

    function test_computeImplementationAddress() external view {
        bytes memory initCode_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(789)));

        address expectedImplementation_ = vm.computeCreate2Address(
            keccak256(initCode_),
            keccak256(initCode_),
            address(_factory)
        );

        assertEq(_factory.computeImplementationAddress(initCode_), expectedImplementation_);
    }

    /* ============ computeProxyAddress ============ */

    function test_computeProxyAddress() external view {
        bytes memory initCode_ = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(_factory.initializableImplementation())
        );

        address expectedProxy_ = vm.computeCreate2Address(
            keccak256(abi.encode(_alice, bytes32(0))),
            keccak256(initCode_),
            address(_factory)
        );

        assertEq(_factory.computeProxyAddress(_alice, bytes32(0)), expectedProxy_);
    }
}
