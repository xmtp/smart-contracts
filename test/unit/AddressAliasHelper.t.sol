// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AddressAliasHelperHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract AddressAliasHelperTests is Test {
    AddressAliasHelperHarness internal _addressAliasHelper;

    function setUp() external {
        _addressAliasHelper = new AddressAliasHelperHarness();
    }

    /* ============ toAlias ============ */

    function test_toAlias() external view {
        assertEq(_addressAliasHelper.toAlias(address(0)), 0x1111000000000000000000000000000000001111);
    }

    /* ============ fromAlias ============ */

    function test_fromAlias() external view {
        assertEq(_addressAliasHelper.fromAlias(0x1111000000000000000000000000000000001111), address(0));
    }
}
