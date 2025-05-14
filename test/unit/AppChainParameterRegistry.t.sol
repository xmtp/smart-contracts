// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { AppChainParameterRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract AppChainParameterRegistryTests is Test {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.appChainParameterRegistry.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.appChainParameterRegistry.migrator";

    AppChainParameterRegistryHarness internal _registry;

    address internal _implementation;
    address internal _admin1 = address(0x1111111111111111111111111111111111111111);
    address internal _admin2 = address(0x2222222222222222222222222222222222222222);

    function setUp() external {
        _implementation = address(new AppChainParameterRegistryHarness());

        address[] memory admins_ = new address[](2);
        admins_[0] = _admin1;
        admins_[1] = _admin2;

        _registry = AppChainParameterRegistryHarness(address(new Proxy(_implementation)));

        _registry.initialize(admins_);
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize(new address[](0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(keccak256(_registry.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(keccak256(_registry.adminParameterKey()), keccak256(_ADMIN_PARAMETER_KEY));

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.appChainParameterRegistry.isAdmin.0x1111111111111111111111111111111111111111"
            ),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.appChainParameterRegistry.isAdmin.0x2222222222222222222222222222222222222222"
            ),
            bytes32(uint256(1))
        );
    }
}
