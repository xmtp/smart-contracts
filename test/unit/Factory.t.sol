// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IInitializable } from "../../src/any-chain/interfaces/IInitializable.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { FactoryHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

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
    string internal constant _PAUSED_KEY = "xmtp.factory.paused";
    string internal constant _MIGRATOR_KEY = "xmtp.factory.migrator";

    FactoryHarness internal _factory;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        _implementation = address(new FactoryHarness(_parameterRegistry));

        vm.prank(_alice);
        _factory = FactoryHarness(address(new Proxy(_implementation)));

        address expectedInitializableImplementation_ = vm.computeCreateAddress(address(_factory), 1);

        vm.expectEmit(address(_factory));
        emit IFactory.InitializableImplementationDeployed(expectedInitializableImplementation_);

        _factory.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IFactory.ZeroParameterRegistry.selector);
        new FactoryHarness(address(0));
    }

    /* ============ initial state ============ */

    function test_initialState_xxx() external view {
        assertEq(Utils.getImplementationFromSlot(address(_factory)), _implementation);
        assertEq(_factory.implementation(), _implementation);
        assertEq(_factory.pausedParameterKey(), _PAUSED_KEY);
        assertEq(_factory.migratorParameterKey(), _MIGRATOR_KEY);
        assertFalse(_factory.paused());
        assertEq(_factory.parameterRegistry(), _parameterRegistry);
        assertEq(_factory.initializableImplementation(), vm.computeCreateAddress(address(_factory), 1));
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _factory.initialize();
    }

    /* ============ deployImplementation ============ */

    function test_deployImplementation_paused() external {
        _factory.__setPauseStatus(true);

        vm.expectRevert(IFactory.Paused.selector);
        _factory.deployImplementation(hex"ff11ff");
    }

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

    function test_deployProxy_paused() external {
        _factory.__setPauseStatus(true);

        vm.expectRevert(IFactory.Paused.selector);
        _factory.deployProxy(address(0), 0, "");
    }

    function test_deployProxy_invalidImplementation() external {
        vm.expectRevert(IFactory.InvalidImplementation.selector);
        _factory.deployProxy(address(0), 0, "");
    }

    function test_deployProxy_deployFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));

        // TODO: Try to mockCallRevert on the expected proxy to get the `create2` to fail, instead of this.
        _factory.deployProxy(address(foo_), 0, "");

        vm.expectRevert(IFactory.DeployFailed.selector);
        _factory.deployProxy(address(foo_), 0, "");
    }

    function test_deployProxy_initializationFailed() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));
        address expectedProxy_ = _getExpectedProxy(_alice, 0);

        vm.mockCallRevert(expectedProxy_, abi.encodeWithSelector(IInitializable.initialize.selector, foo_, ""), "");

        vm.expectRevert();

        vm.prank(_alice);
        _factory.deployProxy(address(foo_), 0, "");
    }

    function test_deployProxy() external {
        address foo_ = address(new Foo(uint256(456), uint256(789)));
        address expectedProxy_ = _getExpectedProxy(_alice, 0);

        bytes memory initializeCallData_ = abi.encodeWithSelector(Foo.initialize.selector, uint256(123));

        vm.expectEmit(address(_factory));
        emit IFactory.ProxyDeployed(expectedProxy_, foo_, _alice, 0, initializeCallData_);

        vm.prank(_alice);
        address proxy_ = _factory.deployProxy(foo_, 0, initializeCallData_);

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
        address expectedProxy_ = _getExpectedProxy(_alice, 0);
        assertEq(_factory.computeProxyAddress(_alice, 0), expectedProxy_);
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _factory.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _factory.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = makeAddr("migrator");

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        bytes memory revertData_ = abi.encodeWithSignature("Failed()");

        vm.mockCallRevert(migrator_, bytes(""), revertData_);

        vm.expectRevert(abi.encodeWithSelector(IMigratable.MigrationFailed.selector, migrator_, revertData_));

        _factory.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _factory.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newImplementation_ = address(new FactoryHarness(newParameterRegistry_));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_factory));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_factory));
        emit IERC1967.Upgraded(newImplementation_);

        _factory.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_factory)), newImplementation_);
        assertEq(_factory.parameterRegistry(), newParameterRegistry_);
    }

    /* ============ helper functions ============ */

    function _getExpectedProxy(address caller_, bytes32 salt_) internal view returns (address expectedProxy_) {
        bytes32 initCodeHash_ = keccak256(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(_factory.initializableImplementation()))
        );

        return vm.computeCreate2Address(keccak256(abi.encode(caller_, salt_)), initCodeHash_, address(_factory));
    }
}
