// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";

import { NodeRegistryBackfillMigrator } from "../../src/any-chain/NodeRegistryBackfillMigrator.sol";

import { Utils } from "../utils/Utils.sol";

contract MockNodeRegistryProxy {
    using EnumerableSet for EnumerableSet.UintSet;

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.NodeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _NODE_REGISTRY_STORAGE_LOCATION =
        0xd48713bc7b5e2644bcb4e26ace7d67dc9027725a9a1ee11596536cc6096a2000;

    struct NodeRegistryStorage {
        address admin;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount; // Not used, use canonicalNodes.length() instead.
        uint32 nodeCount;
        mapping(uint32 nodeId => INodeRegistry.Node node) nodes;
        string baseURI;
        EnumerableSet.UintSet canonicalNodes;
    }

    function _getStorage() internal pure returns (NodeRegistryStorage storage $) {
        assembly {
            $.slot := _NODE_REGISTRY_STORAGE_LOCATION
        }
    }

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

    function __setNodeCount(uint32 count_) external {
        _getStorage().nodeCount = count_;
    }

    function __setNodeCanonical(uint32 nodeId_) external {
        _getStorage().nodes[nodeId_].isCanonical = true;
    }

    function __setNodeNonCanonical(uint32 nodeId_) external {
        _getStorage().nodes[nodeId_].isCanonical = false;
    }

    function __addToCanonicalSet(uint32 nodeId_) external {
        _getStorage().canonicalNodes.add(nodeId_);
    }

    function __getCanonicalNodesCount() external view returns (uint256 count_) {
        return _getStorage().canonicalNodes.length();
    }

    function __isInCanonicalSet(uint32 nodeId_) external view returns (bool isIn_) {
        return _getStorage().canonicalNodes.contains(nodeId_);
    }
}

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

        _proxy.__callMigrator(migrator_);

        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }

    function test_fallback_emitsUpgradedEvent() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        vm.expectEmit(true, false, false, false, address(_proxy));
        emit IERC1967.Upgraded(_implementation);

        _proxy.__callMigrator(migrator_);
    }

    function test_fallback_backfillsCanonicalNodes() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        // 3 nodes: IDs 100, 200, 300 — nodes 100 and 300 are canonical, 200 is not.
        _proxy.__setNodeCount(3);
        _proxy.__setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.__setNodeNonCanonical(2 * _NODE_INCREMENT);
        _proxy.__setNodeCanonical(3 * _NODE_INCREMENT);

        _proxy.__callMigrator(migrator_);

        assertEq(_proxy.__getCanonicalNodesCount(), 2);
        assertTrue(_proxy.__isInCanonicalSet(1 * _NODE_INCREMENT));
        assertFalse(_proxy.__isInCanonicalSet(2 * _NODE_INCREMENT));
        assertTrue(_proxy.__isInCanonicalSet(3 * _NODE_INCREMENT));
    }

    function test_fallback_skipsNonCanonicalNodes() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.__setNodeCount(3);
        _proxy.__setNodeNonCanonical(1 * _NODE_INCREMENT);
        _proxy.__setNodeNonCanonical(2 * _NODE_INCREMENT);
        _proxy.__setNodeNonCanonical(3 * _NODE_INCREMENT);

        _proxy.__callMigrator(migrator_);

        assertEq(_proxy.__getCanonicalNodesCount(), 0);
    }

    function test_fallback_skipsNodesAlreadyInSet() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.__setNodeCount(2);
        _proxy.__setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.__setNodeCanonical(2 * _NODE_INCREMENT);

        // Pre-populate node 100 as if it was partially backfilled.
        _proxy.__addToCanonicalSet(1 * _NODE_INCREMENT);

        _proxy.__callMigrator(migrator_);

        // Both nodes must be in the set — node 100 must not be duplicated.
        assertEq(_proxy.__getCanonicalNodesCount(), 2);
        assertTrue(_proxy.__isInCanonicalSet(1 * _NODE_INCREMENT));
        assertTrue(_proxy.__isInCanonicalSet(2 * _NODE_INCREMENT));
    }

    function test_fallback_isIdempotentWhenCalledTwice() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.__setNodeCount(2);
        _proxy.__setNodeCanonical(1 * _NODE_INCREMENT);
        _proxy.__setNodeCanonical(2 * _NODE_INCREMENT);

        _proxy.__callMigrator(migrator_);
        _proxy.__callMigrator(migrator_);

        assertEq(_proxy.__getCanonicalNodesCount(), 2);
        assertTrue(_proxy.__isInCanonicalSet(1 * _NODE_INCREMENT));
        assertTrue(_proxy.__isInCanonicalSet(2 * _NODE_INCREMENT));
        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }

    function test_fallback_emptyRegistry() external {
        address migrator_ = address(new NodeRegistryBackfillMigrator(_implementation));

        _proxy.__setNodeCount(0);

        _proxy.__callMigrator(migrator_);

        assertEq(_proxy.__getCanonicalNodesCount(), 0);
        assertEq(Utils.getImplementationFromSlot(address(_proxy)), _implementation);
    }
}
