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
    bytes internal constant _MIGRATOR_KEY = "xmtp.acg.migrator";

    address internal _implementation;

    AppChainGatewayHarness internal _gateway;

    address internal _registry;

    address internal _settlementChainGateway = makeAddr("settlementChainGateway");
    address internal _settlementChainGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(_settlementChainGateway);

    function setUp() external {
        _registry = address(new MockParameterRegistry());
        _implementation = address(new AppChainGatewayHarness(_registry, _settlementChainGateway));

        _gateway = AppChainGatewayHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(IAppChainGateway.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroRegistryAddress() external {
        vm.expectRevert(IAppChainGateway.ZeroRegistryAddress.selector);
        new AppChainGatewayHarness(address(0), address(0));
    }

    function test_constructor_zeroSettlementChainGatewayAddress() external {
        vm.expectRevert(IAppChainGateway.ZeroSettlementChainGatewayAddress.selector);
        new AppChainGatewayHarness(_registry, address(0));
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
        assertEq(_gateway.registry(), _registry);
        assertEq(_gateway.settlementChainGateway(), _settlementChainGateway);
        assertEq(_gateway.settlementChainGatewayAlias(), _settlementChainGatewayAlias);
    }

    /* ============ receiveParameters ============ */

    function test_receiveParameters_notSettlementChainGateway() external {
        vm.expectRevert(IAppChainGateway.NotSettlementChainGateway.selector);
        _gateway.receiveParameters(0, new bytes[][](0), new bytes32[](0));
    }

    function test_receiveParameters_emptyKeyChain() external {
        vm.expectRevert(IAppChainGateway.EmptyKeyChain.selector);
        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveParameters(0, new bytes[][](1), new bytes32[](1));
    }

    function test_receiveParameters() external {
        _gateway.__setKeyNonce("this.is.a.skipped.parameter", 1);

        bytes[][] memory keyChains_ = new bytes[][](3);

        keyChains_[0] = new bytes[](5);
        keyChains_[0][0] = "this";
        keyChains_[0][1] = "is";
        keyChains_[0][2] = "a";
        keyChains_[0][3] = "used";
        keyChains_[0][4] = "parameter";

        keyChains_[1] = new bytes[](5);
        keyChains_[1][0] = "this";
        keyChains_[1][1] = "is";
        keyChains_[1][2] = "a";
        keyChains_[1][3] = "skipped";
        keyChains_[1][4] = "parameter";

        keyChains_[2] = new bytes[](5);
        keyChains_[2][0] = "this";
        keyChains_[2][1] = "is";
        keyChains_[2][2] = "another";
        keyChains_[2][3] = "used";
        keyChains_[2][4] = "parameter";

        bytes32[] memory values_ = new bytes32[](3);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));
        values_[2] = bytes32(uint256(98765));

        vm.expectCall(_registry, abi.encodeWithSelector(MockParameterRegistry.set.selector, keyChains_[0], values_[0]));

        // NOTE: (keyChains_[1], values_[1]) is skipped because the nonce is lower than the key's nonce.

        vm.expectCall(_registry, abi.encodeWithSelector(MockParameterRegistry.set.selector, keyChains_[2], values_[2]));

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.ParametersReceived(1, keyChains_);

        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveParameters(1, keyChains_, values_);

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

        _mockRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockRegistryCall(_MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newRegistry_ = makeAddr("newRegistry");
        address newSettlementChainGateway_ = makeAddr("newSettlementChainGateway");

        address newImplementation_ = address(new AppChainGatewayHarness(newRegistry_, newSettlementChainGateway_));

        address migrator_ = address(new MockMigrator(newImplementation_));

        // TODO: `_expectAndMockRegistryCall`.
        _mockRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(_getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.registry(), newRegistry_);
        assertEq(_gateway.settlementChainGateway(), newSettlementChainGateway_);
    }

    /* ============ helper functions ============ */

    function _expectAndMockCall(address callee_, bytes memory data_, bytes memory returnData_) internal {
        vm.expectCall(callee_, data_);
        vm.mockCall(callee_, data_, returnData_);
    }

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
        vm.mockCall(_registry, abi.encodeWithSignature("get(bytes)", key_), abi.encode(value_));
    }

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
