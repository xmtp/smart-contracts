// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { IERC1967 } from "../abstract/interfaces/IERC1967.sol";
import { INodeRegistry } from "../settlement-chain/interfaces/INodeRegistry.sol";

/**
 * @title  NodeRegistryBackfillMigrator
 * @notice One-off migrator that upgrades the NodeRegistry implementation and backfills the
 *         canonicalNodes EnumerableSet. It is a copy of GenericEIP1967Migrator with additional functionality.
 *
 * @dev    This migrator is delegatecalled by the proxy (via the Migratable pattern), so all storage
 *         reads and writes operate on the proxy's storage context.
 *         1. Writes newImpl into the EIP-1967 implementation slot as normally done by a migrator.
 *         2. Additionally, iterates existing nodes and adds canonical nodes to the canonicalNodes set.
 */
contract NodeRegistryBackfillMigrator {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Must match NodeRegistry.NODE_INCREMENT
    uint32 internal constant _NODE_INCREMENT = 100;

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.NodeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _NODE_REGISTRY_STORAGE_LOCATION =
        0xd48713bc7b5e2644bcb4e26ace7d67dc9027725a9a1ee11596536cc6096a2000;

    /// @notice The implementation that the proxy will be upgraded to.
    address public immutable newImpl;

    error InvalidImplementation();

    // Layout copy of NodeRegistry.NodeRegistryStorage. All writes go to the proxy's storage context via delegatecall.
    struct NodeRegistryStorage {
        address admin;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount; // Not used, use canonicalNodes.length() instead.
        uint32 nodeCount;
        mapping(uint32 tokenId => INodeRegistry.Node node) nodes;
        string baseURI;
        EnumerableSet.UintSet canonicalNodes;
    }

    /**
     * @param newImpl_ The address of the new implementation
     */
    constructor(address newImpl_) {
        if (newImpl_ == address(0)) revert InvalidImplementation();
        newImpl = newImpl_;
    }

    /**
     * @dev Runs in the proxy's storage context via delegatecall.
     *      1. Updates the implementation slot.
     *      2. Iterates nodes, if canonical and not already in the set, add it.
     */
    fallback() external {
        address impl = newImpl;

        // slither-disable-next-line assembly
        assembly {
            sstore(_IMPLEMENTATION_SLOT, impl)
        }

        emit IERC1967.Upgraded(impl);

        _backfillCanonicalNodes();
    }

    function _backfillCanonicalNodes() internal {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        uint32 count = $.nodeCount;
        for (uint32 i = 1; i <= count; ++i) {
            uint32 nodeId = i * _NODE_INCREMENT;
            if ($.nodes[nodeId].isCanonical && !$.canonicalNodes.contains(nodeId)) {
                $.canonicalNodes.add(nodeId);
            }
        }
    }

    function _getNodeRegistryStorage() internal pure returns (NodeRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _NODE_REGISTRY_STORAGE_LOCATION
        }
    }
}
