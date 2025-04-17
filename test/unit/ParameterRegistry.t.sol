// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";

import { ParameterRegistryHarness } from "../utils/Harnesses.sol";
import { MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract ParameterRegistryTests is Test, Utils {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.parameterRegistry.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.parameterRegistry.migrator";

    ParameterRegistryHarness internal _registry;

    address internal _implementation;
    address internal _unauthorized = makeAddr("unauthorized");
    address internal _admin1 = address(0x1111111111111111111111111111111111111111);
    address internal _admin2 = address(0x2222222222222222222222222222222222222222);

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
            _registry.__getRegistryParameter(
                "xmtp.parameterRegistry.isAdmin.0x1111111111111111111111111111111111111111"
            ),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.parameterRegistry.isAdmin.0x2222222222222222222222222222222222222222"
            ),
            bytes32(uint256(1))
        );
    }

    /* ============ set several ============ */

    function test_set_several_notAdmin() external {
        vm.expectRevert(IParameterRegistry.NotAdmin.selector);
        vm.prank(_unauthorized);
        _registry.set(new bytes[](0), new bytes32[](0));
    }

    function test_set_several_noKeys() external {
        vm.expectRevert(IParameterRegistry.NoKeys.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[](0), new bytes32[](0));
    }

    function test_set_several_arrayLengthMismatch() external {
        vm.expectRevert(IParameterRegistry.ArrayLengthMismatch.selector);
        vm.prank(_admin1);
        _registry.set(new bytes[](1), new bytes32[](2));
    }

    function test_set_several() external {
        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(1010101));
        values_[1] = bytes32(uint256(2020202));

        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet(keys_[0], values_[0]);

        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet(keys_[1], values_[1]);

        vm.prank(_admin1);
        _registry.set(keys_, values_);

        assertEq(_registry.__getRegistryParameter(keys_[0]), bytes32(uint256(1010101)));
        assertEq(_registry.__getRegistryParameter(keys_[1]), bytes32(uint256(2020202)));
    }

    /* ============ set one ============ */

    function test_set_one_notAdmin() external {
        vm.expectRevert(IParameterRegistry.NotAdmin.selector);
        vm.prank(_unauthorized);
        _registry.set("", bytes32(0));
    }

    function test_set_one() external {
        vm.expectEmit(address(_registry));
        emit IParameterRegistry.ParameterSet("this.is.a.parameter", bytes32(uint256(1010101)));

        vm.prank(_admin1);
        _registry.set("this.is.a.parameter", bytes32(uint256(1010101)));

        assertEq(_registry.__getRegistryParameter("this.is.a.parameter"), bytes32(uint256(1010101)));
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
            _registry.__getRegistryParameter(
                "xmtp.parameterRegistry.isAdmin.0x1111111111111111111111111111111111111111"
            ),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.parameterRegistry.isAdmin.0x2222222222222222222222222222222222222222"
            ),
            bytes32(uint256(1))
        );

        assertEq(_registry.__getRegistryParameter(hex"f1f1f1f1"), bytes32(uint256(1010101)));
    }

    /* ============ isAdmin ============ */

    function test_isAdmin() external {
        assertFalse(_registry.isAdmin(address(1)));

        _registry.__setRegistryParameter(
            "xmtp.parameterRegistry.isAdmin.0x0000000000000000000000000000000000000001",
            bytes32(uint256(1))
        );

        assertTrue(_registry.isAdmin(address(1)));
    }

    /* ============ get several ============ */

    function test_get_several_noKeys() external {
        vm.expectRevert(IParameterRegistry.NoKeys.selector);
        _registry.get(new bytes[](0));
    }

    function test_get_several() external {
        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory expectedValues_ = new bytes32[](2);
        expectedValues_[0] = bytes32(uint256(1010101));
        expectedValues_[1] = bytes32(uint256(2020202));

        _registry.__setRegistryParameter(keys_[0], expectedValues_[0]);
        _registry.__setRegistryParameter(keys_[1], expectedValues_[1]);

        bytes32[] memory values_ = _registry.get(keys_);

        assertEq(values_.length, keys_.length);
        assertEq(values_[0], expectedValues_[0]);
        assertEq(values_[1], expectedValues_[1]);
    }

    /* ============ get one ============ */

    function test_get_one() external {
        _registry.__setRegistryParameter("this.is.a.parameter", bytes32(uint256(1010101)));

        assertEq(_registry.get("this.is.a.parameter"), bytes32(uint256(1010101)));
        assertEq(_registry.get(bytes("this.is.a.parameter")), bytes32(uint256(1010101)));
        assertEq(_registry.get(abi.encodePacked("this.is.a.parameter")), bytes32(uint256(1010101)));

        // NOTE: Encoding a string non-compactly is a different key.
        assertNotEq(_registry.get(abi.encode("this.is.a.parameter")), bytes32(uint256(1010101)));
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
