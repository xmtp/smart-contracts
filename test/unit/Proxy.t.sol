// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IProxy } from "../../src/any-chain/interfaces/IProxy.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { Utils } from "../utils/Utils.sol";

contract Foo {
    error Reverting();

    uint256 public constant CONSTANT_VALUE = 123;

    uint256 public immutable immutableValue;

    uint256 public value;

    constructor(uint256 immutableValue_, uint256 value_) {
        immutableValue = immutableValue_;
        value = value_;
    }

    function initialize(uint256 value_) external {
        value = value_;
    }

    function revertingFunction() external pure {
        revert Reverting();
    }
}

contract ProxyTests is Test {
    /* ============ constructor ============ */

    function test_constructor_zeroImplementation() external {
        vm.expectRevert(IProxy.ZeroImplementation.selector);
        new Proxy(address(0));
    }

    function test_constructor() external {
        address implementation_ = address(new Foo(456, 789));
        address proxy_ = address(new Proxy(implementation_));

        assertEq(Utils.getImplementationFromSlot(proxy_), implementation_);
        assertEq(Foo(proxy_).CONSTANT_VALUE(), 123);
        assertEq(Foo(proxy_).immutableValue(), 456);
        assertEq(Foo(proxy_).value(), 0);
    }

    function test_constructor_initializedStorage() external {
        address implementation_ = address(new Foo(456, 789));
        address proxy_ = address(new Proxy(implementation_));

        Foo(proxy_).initialize(987);

        assertEq(Foo(proxy_).value(), 987);
    }

    /* ============ reverts ============ */

    function test_reverts() external {
        address implementation_ = address(new Foo(456, 789));
        address proxy_ = address(new Proxy(implementation_));

        vm.expectRevert(Foo.Reverting.selector);

        Foo(proxy_).revertingFunction();
    }
}
