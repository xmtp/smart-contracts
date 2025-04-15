// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";

import { AppChainParameterRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract AppChainParameterRegistryTests is Test, Utils {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _ADMIN_PARAMETER_KEY = "xmtp.appChainParameterRegistry.isAdmin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.appChainParameterRegistry.migrator";

    address internal _implementation;

    AppChainParameterRegistryHarness internal _registry;

    address internal _admin1 = address(0x1111111111111111111111111111111111111111);
    address internal _admin2 = address(0x2222222222222222222222222222222222222222);

    function setUp() external {
        _implementation = address(new AppChainParameterRegistryHarness());

        address[] memory admins_ = new address[](2);
        admins_[0] = _admin1;
        admins_[1] = _admin2;

        _registry = AppChainParameterRegistryHarness(
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

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
