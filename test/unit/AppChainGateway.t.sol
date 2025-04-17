// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";

import { AppChainGatewayHarness } from "../utils/Harnesses.sol";

import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract AppChainGatewayTests is Test, Utils {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _MIGRATOR_KEY = "xmtp.appChainGateway.migrator";

    AppChainGatewayHarness internal _gateway;

    address internal _implementation;
    address internal _parameterRegistry;

    address internal _settlementChainGateway = makeAddr("settlementChainGateway");
    address internal _settlementChainGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(_settlementChainGateway);

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new AppChainGatewayHarness(_parameterRegistry, _settlementChainGateway));

        _gateway = AppChainGatewayHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(IAppChainGateway.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistryAddress() external {
        vm.expectRevert(IAppChainGateway.ZeroParameterRegistryAddress.selector);
        new AppChainGatewayHarness(address(0), address(0));
    }

    function test_constructor_zeroSettlementChainGatewayAddress() external {
        vm.expectRevert(IAppChainGateway.ZeroSettlementChainGatewayAddress.selector);
        new AppChainGatewayHarness(_parameterRegistry, address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _gateway.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_gateway)), _implementation);
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

        vm.expectCall(
            _parameterRegistry,
            abi.encodeWithSelector(MockParameterRegistry.set.selector, keys_[0], values_[0])
        );

        // NOTE: (keys_[1], values_[1]) is skipped because the nonce is lower than the key's nonce.

        vm.expectCall(
            _parameterRegistry,
            abi.encodeWithSelector(MockParameterRegistry.set.selector, keys_[2], values_[2])
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

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _gateway.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockParameterRegistryCall(_MIGRATOR_KEY, address(1));

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

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(_getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.parameterRegistry(), newParameterRegistry_);
        assertEq(_gateway.settlementChainGateway(), newSettlementChainGateway_);
    }

    /* ============ helper functions ============ */

    function _expectAndMockCall(address callee_, bytes memory data_, bytes memory returnData_) internal {
        vm.expectCall(callee_, data_);
        vm.mockCall(callee_, data_, returnData_);
    }

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
