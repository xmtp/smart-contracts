// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IInitializable } from "../../src/any-chain/interfaces/IInitializable.sol";

import { Initializable } from "../../src/any-chain/Initializable.sol";

import { Utils } from "../utils/Utils.sol";

contract Foo {
    error Reverting();

    uint256 public value;

    function initialize(uint256 value_) external {
        value = value_;
    }
}

contract InitializableTests is Test {
    Initializable internal _initializable;

    address internal _implementation;

    function setUp() external {
        _initializable = new Initializable();
        _implementation = address(new Foo());
    }

    /* ============ initialize ============ */

    function test_initialize_zeroImplementation() external {
        vm.expectRevert(IInitializable.ZeroImplementation.selector);
        _initializable.initialize(address(0), "");
    }

    function test_initialize_noInitializeCallData() external {
        _initializable.initialize(address(1), "");
        assertEq(Utils.getImplementationFromSlot(address(_initializable)), address(1));
    }

    function test_initialize_initializationFailed() external {
        vm.mockCallRevert(
            address(_implementation),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(1)),
            abi.encodeWithSelector(Foo.Reverting.selector)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IInitializable.InitializationFailed.selector,
                abi.encodeWithSelector(Foo.Reverting.selector)
            )
        );

        _initializable.initialize(
            address(_implementation),
            abi.encodeWithSelector(Foo.initialize.selector, uint256(1))
        );
    }

    function test_initialize_emptyCode() external {
        vm.expectRevert(abi.encodeWithSelector(IInitializable.EmptyCode.selector, address(1)));
        _initializable.initialize(address(1), abi.encodeWithSelector(Foo.initialize.selector, uint256(1)));
    }
}
