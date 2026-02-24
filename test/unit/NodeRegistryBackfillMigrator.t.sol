// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";

import { NodeRegistryBackfillMigrator } from "../../src/any-chain/NodeRegistryBackfillMigrator.sol";

import { MockNodeRegistryProxy } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract NodeRegistryBackfillMigratorTests is Test {
    uint32 internal constant _NODE_INCREMENT = 100;

    MockNodeRegistryProxy internal _proxy;

    address internal _implementation = makeAddr("implementation");

    function setUp() external {
        _proxy = new MockNodeRegistryProxy();
    }

    /* ============ constructor ============ */

    function test_constructor_invalidImplementation() external {
        vm.expectRevert(NodeRegistryBackfillMigrator.InvalidImplementation.selector);
        new NodeRegistryBackfillMigrator(address(0));
    }

    function test_constructor() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));
        assertEq(NodeRegistryBackfillMigrator(migrator_).newImpl(), _implementation);
    }

    /* ============ fallback ============ */

    function test_fallback_writesImplementationSlot() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.callMigrator(migrator_);

        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }

    function test_fallback_emitsUpgradedEvent() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        vm.expectEmit(true, false, false, false, address(_proxy));
        emit IERC1967.Upgraded(_implementation);

        _proxy.callMigrator(migrator_);
    }

    function test_fallback_backfillsCanonicalNodes() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        // 3 nodes: IDs 100, 200, 300 — nodes 100 and 300 are canonical, 200 is not.
        _proxy.setNodeCount(3);
        _proxy.setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.setNodeNonCanonical(2 * _NODE_INCREMENT);
        _proxy.setNodeCanonical(3 * _NODE_INCREMENT);

        _proxy.callMigrator(migrator_);

        assertEq(_proxy.getCanonicalNodesCount(), 2);
        assertTrue(_proxy.isInCanonicalSet(1 * _NODE_INCREMENT));
        assertFalse(_proxy.isInCanonicalSet(2 * _NODE_INCREMENT));
        assertTrue(_proxy.isInCanonicalSet(3 * _NODE_INCREMENT));
    }

    function test_fallback_skipsNonCanonicalNodes() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.setNodeCount(3);
        _proxy.setNodeNonCanonical(1 * _NODE_INCREMENT);
        _proxy.setNodeNonCanonical(2 * _NODE_INCREMENT);
        _proxy.setNodeNonCanonical(3 * _NODE_INCREMENT);

        _proxy.callMigrator(migrator_);

        assertEq(_proxy.getCanonicalNodesCount(), 0);
    }

    function test_fallback_skipsNodesAlreadyInSet() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.setNodeCount(2);
        _proxy.setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.setNodeCanonical(2 * _NODE_INCREMENT);

        // Pre-populate node 100 as if it was partially backfilled.
        _proxy.addToCanonicalSet(1 * _NODE_INCREMENT);

        _proxy.callMigrator(migrator_);

        // Both nodes must be in the set — node 100 must not be duplicated.
        assertEq(_proxy.getCanonicalNodesCount(), 2);
        assertTrue(_proxy.isInCanonicalSet(1 * _NODE_INCREMENT));
        assertTrue(_proxy.isInCanonicalSet(2 * _NODE_INCREMENT));
    }

    function test_fallback_isIdempotentWhenCalledTwice() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.setNodeCount(2);
        _proxy.setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.setNodeCanonical(2 * _NODE_INCREMENT);

        _proxy.callMigrator(migrator_);
        _proxy.callMigrator(migrator_);

        assertEq(_proxy.getCanonicalNodesCount(), 2);
        assertTrue(_proxy.isInCanonicalSet(1 * _NODE_INCREMENT));
        assertTrue(_proxy.isInCanonicalSet(2 * _NODE_INCREMENT));
        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }

    function test_fallback_emptyRegistry() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.setNodeCount(0);

        _proxy.callMigrator(migrator_);

        assertEq(_proxy.getCanonicalNodesCount(), 0);
        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }
}
