// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IParameterKeysErrors } from "../../src/libraries/interfaces/IParameterKeysErrors.sol";

import { ParameterKeysHarness } from "../utils/Harnesses.sol";

contract ParameterKeysTests is Test {
    ParameterKeysHarness internal _parameterKeys;

    function setUp() external {
        _parameterKeys = new ParameterKeysHarness();
    }

    /* ============ getKey ============ */

    function test_getKey_noKeyComponents() external {
        vm.expectRevert(IParameterKeysErrors.NoKeyComponents.selector);
        _parameterKeys.getKey(new bytes[](0));
    }

    function test_getKey() external view {
        bytes[] memory keyComponents_ = new bytes[](4);
        keyComponents_[0] = "this";
        keyComponents_[1] = "is";
        keyComponents_[2] = "a";
        keyComponents_[3] = "key";

        bytes memory key_ = _parameterKeys.getKey(keyComponents_);
        assertEq(key_, "this.is.a.key");
    }

    /* ============ combineKeyComponents ============ */

    function test_combineKeyComponents() external view {
        bytes memory left_ = "left";
        bytes memory right_ = "right";

        bytes memory key_ = _parameterKeys.combineKeyComponents(left_, right_);
        assertEq(key_, "left.right");
    }

    /* ============ addressToKeyComponent ============ */

    function test_addressToKeyComponent() external view {
        assertEq(
            _parameterKeys.addressToKeyComponent(address(0x0000000000000000000000000000000000000001)),
            "0x0000000000000000000000000000000000000001"
        );

        assertEq(
            _parameterKeys.addressToKeyComponent(address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12)),
            "0xabcdef1234567890abcdef1234567890abcdef12"
        );
    }

    /* ============ uint256ToKeyComponent ============ */

    function test_uint256ToKeyComponent() external view {
        assertEq(_parameterKeys.uint256ToKeyComponent(uint256(1)), "1");
        assertEq(_parameterKeys.uint256ToKeyComponent(uint256(100)), "100");
        assertEq(_parameterKeys.uint256ToKeyComponent(uint256(1000000)), "1000000");
        assertEq(_parameterKeys.uint256ToKeyComponent(uint256(1000000000000000000)), "1000000000000000000");
    }
}
