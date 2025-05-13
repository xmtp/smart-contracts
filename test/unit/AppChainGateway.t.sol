// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { AppChainGatewayHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract AppChainGatewayTests is Test {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _MIGRATOR_KEY = "xmtp.appChainGateway.migrator";

    AppChainGatewayHarness internal _gateway;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _settlementChainGateway = makeAddr("settlementChainGateway");
    address internal _settlementChainGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(_settlementChainGateway);

    function setUp() external {
        _implementation = address(new AppChainGatewayHarness(_parameterRegistry, _settlementChainGateway));
        _gateway = AppChainGatewayHarness(address(new Proxy(_implementation)));

        _gateway.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IAppChainGateway.ZeroParameterRegistry.selector);
        new AppChainGatewayHarness(address(0), address(0));
    }

    function test_constructor_zeroSettlementChainGateway() external {
        vm.expectRevert(IAppChainGateway.ZeroSettlementChainGateway.selector);
        new AppChainGatewayHarness(_parameterRegistry, address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _gateway.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_gateway)), _implementation);
        assertEq(_gateway.implementation(), _implementation);
        assertEq(keccak256(_gateway.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(_gateway.parameterRegistry(), _parameterRegistry);
        assertEq(_gateway.settlementChainGateway(), _settlementChainGateway);
        assertEq(_gateway.settlementChainGatewayAlias(), _settlementChainGatewayAlias);
    }

    /* ============ receiveParameters ============ */

    function test_receiveParameters_notSettlementChainGateway() external {
        vm.expectRevert(IAppChainGateway.NotSettlementChainGateway.selector);
        _gateway.receiveParameters(0, new bytes[](0), new bytes32[](0));
    }

    function test_receiveParameters() external {
        _gateway.__setKeyNonce("this.is.a.skipped.parameter", 1);

        bytes[] memory keys_ = new bytes[](3);

        keys_[0] = "this.is.a.used.parameter";
        keys_[1] = "this.is.a.skipped.parameter";
        keys_[2] = "this.is.another.used.parameter";

        bytes32[] memory values_ = new bytes32[](3);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));
        values_[2] = bytes32(uint256(98765));

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("set(bytes,bytes32)", keys_[0], values_[0]),
            ""
        );

        // NOTE: (keys_[1], values_[1]) is skipped because the nonce is lower than the key's nonce.

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("set(bytes,bytes32)", keys_[2], values_[2]),
            ""
        );

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.ParametersReceived(1, keys_);

        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveParameters(1, keys_, values_);

        assertEq(_gateway.__getKeyNonce("this.is.a.used.parameter"), 1);
        assertEq(_gateway.__getKeyNonce("this.is.a.skipped.parameter"), 1);
        assertEq(_gateway.__getKeyNonce("this.is.another.used.parameter"), 1);
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(0)));
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _gateway.migrate();
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

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newSettlementChainGateway_ = makeAddr("newSettlementChainGateway");

        address newImplementation_ = address(
            new AppChainGatewayHarness(newParameterRegistry_, newSettlementChainGateway_)
        );

        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.parameterRegistry(), newParameterRegistry_);
        assertEq(_gateway.settlementChainGateway(), newSettlementChainGateway_);
    }
}
