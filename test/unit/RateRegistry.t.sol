// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/oz/contracts/access/IAccessControl.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "../../lib/oz-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { RateRegistry } from "../../src/RateRegistry.sol";

import { RateRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract RateRegistryTests is Test, Utils {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant RATES_MANAGER_ROLE = keccak256("RATES_MANAGER_ROLE");

    uint256 constant PAGE_SIZE = 50;

    uint64 constant MESSAGE_FEE = 100;
    uint64 constant STORAGE_FEE = 200;
    uint64 constant CONGESTION_FEE = 300;
    uint64 constant TARGET_RATE_PER_MINUTE = 100 * 60;

    address implementation;

    RateRegistryHarness registry;

    address admin = makeAddr("admin");
    address unauthorized = makeAddr("unauthorized");

    function setUp() public {
        implementation = address(new RateRegistryHarness());

        registry = RateRegistryHarness(
            address(new ERC1967Proxy(implementation, abi.encodeWithSelector(RateRegistry.initialize.selector, admin)))
        );
    }

    /* ============ initializer ============ */

    function test_initializer_zeroAdminAddress() public {
        vm.expectRevert(RateRegistry.ZeroAdminAddress.selector);

        new ERC1967Proxy(implementation, abi.encodeWithSelector(RateRegistry.initialize.selector, address(0)));
    }

    /* ============ initial state ============ */

    function test_initialState() public view {
        assertEq(_getImplementationFromSlot(address(registry)), implementation);
        assertEq(registry.__getAllRates().length, 0);
    }

    /* ============ addRates ============ */

    function test_addRates_notManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                RATES_MANAGER_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.addRates(0, 0, 0, 0, 0);

        // TODO: Test where admin is not the manager.
    }

    function test_addRates_first() public {
        vm.expectEmit(address(registry));
        emit RateRegistry.RatesAdded(100, 200, 300, 400, 500);

        vm.prank(admin);
        registry.addRates(100, 200, 300, 400, 500);

        RateRegistry.Rates[] memory rates = registry.__getAllRates();

        assertEq(rates.length, 1);

        assertEq(rates[0].messageFee, 100);
        assertEq(rates[0].storageFee, 200);
        assertEq(rates[0].congestionFee, 300);
        assertEq(rates[0].targetRatePerMinute, 400);
        assertEq(rates[0].startTime, 500);
    }

    function test_addRates_nth() public {
        registry.__pushRates(0, 0, 0, 0, 0);
        registry.__pushRates(0, 0, 0, 0, 0);
        registry.__pushRates(0, 0, 0, 0, 0);
        registry.__pushRates(0, 0, 0, 0, 0);

        vm.expectEmit(address(registry));
        emit RateRegistry.RatesAdded(100, 200, 300, 400, 500);

        vm.prank(admin);
        registry.addRates(100, 200, 300, 400, 500);

        RateRegistry.Rates[] memory rates = registry.__getAllRates();

        assertEq(rates.length, 5);

        assertEq(rates[4].messageFee, 100);
        assertEq(rates[4].storageFee, 200);
        assertEq(rates[4].congestionFee, 300);
        assertEq(rates[4].targetRatePerMinute, 400);
        assertEq(rates[4].startTime, 500);
    }

    function test_addRates_invalidStartTime() public {
        registry.__pushRates(0, 0, 0, 0, 100);

        vm.expectRevert(RateRegistry.InvalidStartTime.selector);

        vm.prank(admin);
        registry.addRates(0, 0, 0, 0, 100);
    }

    /* ============ getRates ============ */

    function test_getRates_emptyArray() public view {
        (RateRegistry.Rates[] memory rates, bool hasMore) = registry.getRates(0);

        assertEq(rates.length, 0);
        assertFalse(hasMore);
    }

    function test_getRates_withinPageSize() public {
        for (uint256 i; i < 3 * PAGE_SIZE; ++i) {
            registry.__pushRates(i, i, i, i, i);
        }

        (RateRegistry.Rates[] memory rates, bool hasMore) = registry.getRates((3 * PAGE_SIZE) - 10);

        assertEq(rates.length, 10);
        assertFalse(hasMore);

        for (uint256 i; i < rates.length; ++i) {
            assertEq(rates[i].messageFee, i + (3 * PAGE_SIZE) - 10);
            assertEq(rates[i].storageFee, i + (3 * PAGE_SIZE) - 10);
            assertEq(rates[i].congestionFee, i + (3 * PAGE_SIZE) - 10);
            assertEq(rates[i].startTime, i + (3 * PAGE_SIZE) - 10);
        }
    }

    function test_getRates_pagination() public {
        for (uint256 i; i < 3 * PAGE_SIZE; ++i) {
            registry.__pushRates(i, i, i, i, i);
        }

        (RateRegistry.Rates[] memory rates, bool hasMore) = registry.getRates(0);

        assertEq(rates.length, PAGE_SIZE);
        assertTrue(hasMore);

        for (uint256 i; i < rates.length; ++i) {
            assertEq(rates[i].messageFee, i);
            assertEq(rates[i].storageFee, i);
            assertEq(rates[i].congestionFee, i);
            assertEq(rates[i].targetRatePerMinute, i);
            assertEq(rates[i].startTime, i);
        }
    }

    /* ============ getRatesCount ============ */

    function test_getRatesCount() public {
        assertEq(registry.getRatesCount(), 0);

        for (uint256 i = 1; i <= 1000; ++i) {
            registry.__pushRates(0, 0, 0, 0, 0);
            assertEq(registry.getRatesCount(), i);
        }
    }

    /* ============ pause ============ */

    function test_pause() public {
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Paused(admin);

        vm.prank(admin);
        registry.pause();

        assertTrue(registry.paused());
    }

    function test_pause_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.pause();
    }

    function test_pause_whenPaused() public {
        registry.__pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(admin);
        registry.pause();
    }

    /* ============ unpause ============ */

    function test_unpause() public {
        registry.__pause();

        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Unpaused(admin);

        vm.prank(admin);
        registry.unpause();

        assertFalse(registry.paused());
    }

    function test_unpause_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.unpause();
    }

    function test_unpause_whenNotPaused() public {
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);

        vm.prank(admin);
        registry.unpause();
    }

    /* ============ upgradeToAndCall ============ */

    function test_upgradeToAndCall_notAdmin() public {
        // Unauthorized upgrade attempts should revert.
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        registry.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall_zeroImplementationAddress() public {
        vm.expectRevert(RateRegistry.ZeroImplementationAddress.selector);

        vm.prank(admin);
        registry.upgradeToAndCall(address(0), "");
    }

    function test_upgradeToAndCall() public {
        registry.__pushRates(0, 0, 0, 0, 0);
        registry.__pushRates(1, 1, 1, 1, 1);
        registry.__pushRates(2, 2, 2, 2, 2);

        address newImplementation = address(new RateRegistryHarness());

        // Authorized upgrade should succeed and emit UpgradeAuthorized event.
        vm.expectEmit(address(registry));
        emit RateRegistry.UpgradeAuthorized(admin, newImplementation);

        vm.prank(admin);
        registry.upgradeToAndCall(newImplementation, "");

        assertEq(_getImplementationFromSlot(address(registry)), newImplementation);

        RateRegistry.Rates[] memory rates = registry.__getAllRates();

        assertEq(rates.length, 3);

        assertEq(rates[0].messageFee, 0);
        assertEq(rates[0].storageFee, 0);
        assertEq(rates[0].congestionFee, 0);
        assertEq(rates[0].startTime, 0);

        assertEq(rates[1].messageFee, 1);
        assertEq(rates[1].storageFee, 1);
        assertEq(rates[1].congestionFee, 1);
        assertEq(rates[1].targetRatePerMinute, 1);
        assertEq(rates[1].startTime, 1);

        assertEq(rates[2].messageFee, 2);
        assertEq(rates[2].storageFee, 2);
        assertEq(rates[2].congestionFee, 2);
        assertEq(rates[2].targetRatePerMinute, 2);
        assertEq(rates[2].startTime, 2);
    }

    /* ============ helper functions ============ */

    function _getImplementationFromSlot(address proxy) internal view returns (address) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
