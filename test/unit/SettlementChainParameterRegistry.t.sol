// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";

import { SettlementChainParameterRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract SettlementChainParameterRegistryTests is Test, Utils {
    bytes internal constant _DELIMITER = bytes(".");
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.scpr.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.scpr.migrator";

    address internal _implementation;

    SettlementChainParameterRegistryHarness internal _registry;

    address internal _admin1 = makeAddr("admin1");
    address internal _admin2 = makeAddr("admin2");

    function setUp() external {
        _implementation = address(new SettlementChainParameterRegistryHarness());

        address[] memory admins_ = new address[](2);
        admins_[0] = _admin1;
        admins_[1] = _admin2;

        _registry = SettlementChainParameterRegistryHarness(
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
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DELIMITER, abi.encode(_admin1))),
            bytes32(uint256(1))
        );

        assertEq(
            _registry.__getRegistryParameter(abi.encodePacked(_ADMIN_PARAMETER_KEY, _DELIMITER, abi.encode(_admin2))),
            bytes32(uint256(1))
        );
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
