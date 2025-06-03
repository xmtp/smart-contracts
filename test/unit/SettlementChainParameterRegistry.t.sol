// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { SettlementChainParameterRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract SettlementChainParameterRegistryTests is Test {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.settlementChainParameterRegistry.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.settlementChainParameterRegistry.migrator";

    SettlementChainParameterRegistryHarness internal _registry;

    address internal _implementation;

    address internal _admin1 = address(0x1111111111111111111111111111111111111111);
    address internal _admin2 = address(0x2222222222222222222222222222222222222222);

    function setUp() external {
        _implementation = address(new SettlementChainParameterRegistryHarness());

        address[] memory admins_ = new address[](2);
        admins_[0] = _admin1;
        admins_[1] = _admin2;

        _registry = SettlementChainParameterRegistryHarness(address(new Proxy(_implementation)));

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
        assertEq(_registry.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_registry.adminParameterKey(), _ADMIN_PARAMETER_KEY);

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.settlementChainParameterRegistry.isAdmin.0x1111111111111111111111111111111111111111"
            ),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(
                "xmtp.settlementChainParameterRegistry.isAdmin.0x2222222222222222222222222222222222222222"
            ),
            bytes32(uint256(1))
        );
    }
}
