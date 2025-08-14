// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Migrator } from "../../src/any-chain/Migrator.sol";

import { Utils } from "../utils/Utils.sol";

contract MockProxy {
    function __setImplementation(address implementation_) external {
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, implementation_)
        }
    }

    function __callMigrator(address migrator_) external {
        (bool success_, bytes memory data_) = migrator_.delegatecall("");

        if (success_) return;

        assembly {
            revert(add(data_, 0x20), mload(data_))
        }
    }
}

contract MigratorTests is Test {
    /* ============ constructor ============ */

    function test_constructor_zeroFromImplementation() external {
        vm.expectRevert(Migrator.ZeroFromImplementation.selector);
        new Migrator(address(0), address(0));
    }

    function test_constructor_zeroToImplementation() external {
        vm.expectRevert(Migrator.ZeroToImplementation.selector);
        new Migrator(address(1), address(0));
    }

    function test_constructor() external {
        address migrator_ = address(new Migrator(address(1), address(2)));

        assertEq(Migrator(migrator_).fromImplementation(), address(1));
        assertEq(Migrator(migrator_).toImplementation(), address(2));
    }

    /* ============ fallback ============ */

    function test_fallback_unexpectedImplementation() external {
        MockProxy proxy_ = new MockProxy();
        address migrator_ = address(new Migrator(address(1), address(2)));

        vm.expectRevert(Migrator.UnexpectedImplementation.selector);

        proxy_.__callMigrator(migrator_);
    }

    function test_fallback() external {
        MockProxy proxy_ = new MockProxy();
        proxy_.__setImplementation(address(1));

        address migrator_ = address(new Migrator(address(1), address(2)));

        proxy_.__callMigrator(migrator_);

        assertEq(Utils.getImplementationFromSlot(address(proxy_)), address(2));
    }
}
