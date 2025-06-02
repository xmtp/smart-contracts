// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AddressAliasHelperHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract AddressAliasHelperTests is Test {
    uint160 internal constant _OFFSET = uint160(0x1111000000000000000000000000000000001111);

    AddressAliasHelperHarness internal _addressAliasHelper;

    function setUp() external {
        _addressAliasHelper = new AddressAliasHelperHarness();
    }

    /* ============ toAlias ============ */

    function test_toAlias() external view {
        assertEq(_addressAliasHelper.toAlias(address(0)), address(_OFFSET));
    }

    function test_toAlias_overflow() external view {
        assertEq(_addressAliasHelper.toAlias(address(type(uint160).max)), address(_OFFSET - 1));
    }

    /* ============ fromAlias ============ */

    function test_fromAlias() external view {
        assertEq(_addressAliasHelper.fromAlias(address(_OFFSET)), address(0));
    }

    function test_fromAlias_underflow() external view {
        assertEq(_addressAliasHelper.fromAlias(address(0)), address(type(uint160).max - _OFFSET + 1));
    }

    /* ============ round trips ============ */

    function test_toAlias_fromAlias_roundtrip() external {
        address account_ = makeAddr("account");
        assertEq(_addressAliasHelper.fromAlias(_addressAliasHelper.toAlias(account_)), account_);
    }

    function test_fromAlias_toAlias_roundtrip() external {
        address account_ = makeAddr("account");
        assertEq(_addressAliasHelper.toAlias(_addressAliasHelper.fromAlias(account_)), account_);
    }
}
