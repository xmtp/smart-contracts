// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/interfaces/IERC1967.sol";
import { IParameterRegistry } from "../../src/interfaces/IParameterRegistry.sol";
import { IMigratable } from "../../src/interfaces/IMigratable.sol";

import { ParameterRegistryHarness } from "../utils/Harnesses.sol";
import { MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract ParameterRegistryTests is Test, Utils {
    bytes internal constant _DOT = bytes(".");
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.appchain.pr.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.appchain.pr.migrator";

    address internal _implementation;

    ParameterRegistryHarness internal _registry;

    address internal _unauthorized = makeAddr("unauthorized");
    address internal _admin1 = makeAddr("admin1");
    address internal _admin2 = makeAddr("admin2");

    function setUp() external {
        _implementation = address(new ParameterRegistryHarness());

        address[] memory admins_ = new address[](2);
        admins_[0] = _admin1;
        admins_[1] = _admin2;

        _registry = ParameterRegistryHarness(
            address(
                new ERC1967Proxy(
                    _implementation,
                    abi.encodeWithSelector(IParameterRegistry.initialize.selector, admins_)
                )
            )
        );
    }

    function test_xxx() external {
        console.logBytes32(
            keccak256(abi.encode(uint256(keccak256("xmtp.storage.SettlementGateway")) - 1)) & ~bytes32(uint256(0xff))
        );
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize(new address[](0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(keccak256(_registry.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(keccak256(_registry.adminParameterKey()), keccak256(_ADMIN_PARAMETER_KEY));

        assertEq(
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DOT, abi.encode(_admin1))),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DOT, abi.encode(_admin2))),
            bytes32(uint256(1))
        );
    }

    /* ============ set several ============ */

    function test_set_several_notAdmin() external {
        vm.expectRevert(IParameterRegistry.NotAdmin.selector);
        vm.prank(_unauthorized);
        _registry.set(new bytes[][](0), new bytes32[](0));
    }

    function test_set_several_noKeyChains() external {
        vm.expectRevert(IParameterRegistry.NoKeyChains.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[][](0), new bytes32[](0));
    }

    function test_set_several_arrayLengthMismatch() external {
        vm.expectRevert(IParameterRegistry.ArrayLengthMismatch.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[][](1), new bytes32[](2));
    }

    function test_set_several_emptyKeyChain() external {
        vm.expectRevert(IParameterRegistry.EmptyKeyChain.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[][](1), new bytes32[](1));
    }

    function test_set_several() external {
        bytes[][] memory keyChains_ = new bytes[][](2);

        keyChains_[0] = new bytes[](4);
        keyChains_[0][0] = abi.encodePacked("this");
        keyChains_[0][1] = abi.encodePacked("is");
        keyChains_[0][2] = abi.encodePacked("one");
        keyChains_[0][3] = abi.encodePacked("test");

        keyChains_[1] = new bytes[](4);
        keyChains_[1][0] = abi.encodePacked("this");
        keyChains_[1][1] = abi.encodePacked("is");
        keyChains_[1][2] = abi.encodePacked("another");
        keyChains_[1][3] = abi.encodePacked("test");

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(1010101));
        values_[1] = bytes32(uint256(2020202));

        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet(abi.encodePacked("this.is.one.test"), keyChains_[0], values_[0]);

        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet(abi.encodePacked("this.is.another.test"), keyChains_[1], values_[1]);

        vm.prank(_admin1);
        _registry.set(keyChains_, values_);

        assertEq(_registry.__getRegistryParameter(abi.encodePacked("this.is.one.test")), bytes32(uint256(1010101)));
        assertEq(_registry.__getRegistryParameter(abi.encodePacked("this.is.another.test")), bytes32(uint256(2020202)));
    }

    /* ============ set one ============ */

    function test_set_one_notAdmin() external {
        vm.expectRevert(IParameterRegistry.NotAdmin.selector);
        vm.prank(_unauthorized);
        _registry.set(new bytes[](0), bytes32(0));
    }

    function test_set_one_emptyKeyChain() external {
        vm.expectRevert(IParameterRegistry.EmptyKeyChain.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[](0), bytes32(0));
    }

    function test_set_one() external {
        bytes[] memory keyChain_ = new bytes[](4);
        keyChain_[0] = abi.encodePacked("this");
        keyChain_[1] = abi.encodePacked("is");
        keyChain_[2] = abi.encodePacked("a");
        keyChain_[3] = abi.encodePacked("test");

        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet(abi.encodePacked("this.is.a.test"), keyChain_, bytes32(uint256(1010101)));

        vm.prank(_admin1);
        _registry.set(keyChain_, bytes32(uint256(1010101)));

        assertEq(_registry.__getRegistryParameter(abi.encodePacked("this.is.a.test")), bytes32(uint256(1010101)));
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _registry.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        _registry.__setRegistryParameter(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _registry.migrate();
    }

    function test_migrate_emptyCode() external {
        _registry.__setRegistryParameter(_MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _registry.migrate();
    }

    function test_migrate() external {
        _registry.__setRegistryParameter(hex"f1f1f1f1", bytes32(uint256(1010101)));

        address newImplementation_ = address(new ParameterRegistryHarness());
        address migrator_ = address(new MockMigrator(newImplementation_));

        _registry.__setRegistryParameter(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_registry));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation_);

        _registry.migrate();

        assertEq(_getImplementationFromSlot(address(_registry)), newImplementation_);
        assertEq(_registry.implementation(), newImplementation_);

        assertEq(
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DOT, abi.encode(_admin1))),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DOT, abi.encode(_admin2))),
            bytes32(uint256(1))
        );

        assertEq(_registry.__getRegistryParameter(hex"f1f1f1f1"), bytes32(uint256(1010101)));
    }

    /* ============ isAdmin ============ */

    function test_isAdmin() external {
        assertFalse(_registry.isAdmin(address(1)));

        _registry.__setRegistryParameter(
            abi.encodePacked(_ADMIN_PARAMETER_KEY, _DOT, abi.encode(address(1))),
            bytes32(uint256(1))
        );

        assertTrue(_registry.isAdmin(address(1)));
    }

    /* ============ get several ============ */

    function test_get_several_noKeyChains() external {
        vm.expectRevert(IParameterRegistry.NoKeyChains.selector);
        _registry.get(new bytes[][](0));
    }

    function test_get_several_emptyKeyChain() external {
        vm.expectRevert(IParameterRegistry.EmptyKeyChain.selector);
        _registry.get(new bytes[][](1));
    }

    function test_get_several() external {
        bytes[][] memory keyChains_ = new bytes[][](2);

        keyChains_[0] = new bytes[](4);
        keyChains_[0][0] = abi.encodePacked("this");
        keyChains_[0][1] = abi.encodePacked("is");
        keyChains_[0][2] = abi.encodePacked("one");
        keyChains_[0][3] = abi.encodePacked("test");

        keyChains_[1] = new bytes[](4);
        keyChains_[1][0] = abi.encodePacked("this");
        keyChains_[1][1] = abi.encodePacked("is");
        keyChains_[1][2] = abi.encodePacked("another");
        keyChains_[1][3] = abi.encodePacked("test");

        bytes32[] memory expectedValues_ = new bytes32[](2);
        expectedValues_[0] = bytes32(uint256(1010101));
        expectedValues_[1] = bytes32(uint256(2020202));

        _registry.__setRegistryParameter(abi.encodePacked("this.is.one.test"), expectedValues_[0]);
        _registry.__setRegistryParameter(abi.encodePacked("this.is.another.test"), expectedValues_[1]);

        bytes32[] memory values_ = _registry.get(keyChains_);

        assertEq(values_.length, values_.length);
        assertEq(values_[0], expectedValues_[0]);
        assertEq(values_[1], expectedValues_[1]);
    }

    /* ============ get one ============ */

    function test_get_one_emptyKeyChain() external {
        vm.expectRevert(IParameterRegistry.EmptyKeyChain.selector);
        _registry.get(new bytes[](0));
    }

    function test_get_one() external {
        bytes[] memory keyChain_ = new bytes[](4);
        keyChain_[0] = abi.encodePacked("this");
        keyChain_[1] = abi.encodePacked("is");
        keyChain_[2] = abi.encodePacked("a");
        keyChain_[3] = abi.encodePacked("test");

        _registry.__setRegistryParameter(abi.encodePacked("this.is.a.test"), bytes32(uint256(1010101)));

        assertEq(_registry.get(keyChain_), bytes32(uint256(1010101)));
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
