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
        vm.prank(_alice);
        _factory = new Factory();
    }

    /* ============ constructor ============ */

    function test_constructor() external {
        address expectedFactory_ = vm.computeCreateAddress(_alice, 1);
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
        vm.expectRevert(IFactory.DeployFailed.selector);
        _factory.deployImplementation(hex"ff11ff");
    }

    function test_deployImplementation() external {
        bytes memory initCode_ = abi.encodePacked(type(Foo).creationCode, abi.encode(uint256(456), uint256(789)));
        bytes32 bytecodeHash_ = keccak256(initCode_);

        address expectedImplementation_ = vm.computeCreate2Address(bytecodeHash_, bytecodeHash_, address(_factory));

        vm.expectEmit(address(_factory));
        emit IFactory.ImplementationDeployed(expectedImplementation_, bytecodeHash_);

        address foo_ = _factory.deployImplementation(initCode_);

        assertEq(foo_, expectedImplementation_);
        assertEq(Foo(foo_).CONSTANT_VALUE(), 123);
        assertEq(Foo(foo_).immutableValue(), 456);
        assertEq(Foo(foo_).value(), 789);
    }

    /* ============ deployProxy ============ */

    function test_deployProxy_deployFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));

        // TODO: Try to mockCallRevert on the expected proxy to get the `create2` to fail, instead of this.
        _factory.deployProxy(address(foo_), bytes32(0), "");

        vm.expectRevert(IFactory.DeployFailed.selector);
        _factory.deployProxy(address(foo_), bytes32(0), "");
    }

    function test_deployProxy_initializationFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));
        address expectedProxy_ = _getExpectedProxy(_alice, bytes32(0));

        vm.mockCallRevert(
            expectedProxy_,
            abi.encodeWithSelector(IInitializable.initialize.selector, foo_, bytes("")),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _factory.deployProxy(address(foo_), bytes32(0), "");
    }

    function test_deployProxy() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));
        address expectedProxy_ = _getExpectedProxy(_alice, bytes32(0));

        bytes memory initializeCallData_ = abi.encodeWithSelector(Foo.initialize.selector, uint256(123));

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
        address expectedProxy_ = _getExpectedProxy(_alice, bytes32(0));
        assertEq(_factory.computeProxyAddress(_alice, bytes32(0)), expectedProxy_);
    }

    /* ============ helper functions ============ */

    function _getExpectedProxy(address caller_, bytes32 salt_) internal view returns (address expectedProxy_) {
        bytes32 initCodeHash_ = keccak256(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(_factory.initializableImplementation()))
        );

        return vm.computeCreate2Address(keccak256(abi.encode(caller_, salt_)), initCodeHash_, address(_factory));
    }
}
