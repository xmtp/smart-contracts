// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { GroupMessageBroadcaster } from "../../src/GroupMessageBroadcaster.sol";
import { IdentityUpdateBroadcaster } from "../../src/IdentityUpdateBroadcaster.sol";
import { NodeRegistry } from "../../src/NodeRegistry.sol";
import { RateRegistry } from "../../src/RateRegistry.sol";

contract GroupMessageBroadcasterHarness is GroupMessageBroadcaster {
    function __pause() external {
        _pause();
    }

    function __unpause() external {
        _unpause();
    }

    function __setSequenceId(uint64 sequenceId) external {
        _getGroupMessagesStorage().sequenceId = sequenceId;
    }

    function __setMinPayloadSize(uint256 minPayloadSize) external {
        _getGroupMessagesStorage().minPayloadSize = minPayloadSize;
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize) external {
        _getGroupMessagesStorage().maxPayloadSize = maxPayloadSize;
    }

    function __getSequenceId() external view returns (uint64) {
        return _getGroupMessagesStorage().sequenceId;
    }
}

contract IdentityUpdateBroadcasterHarness is IdentityUpdateBroadcaster {
    function __pause() external {
        _pause();
    }

    function __unpause() external {
        _unpause();
    }

    function __setSequenceId(uint64 sequenceId) external {
        _getIdentityUpdatesStorage().sequenceId = sequenceId;
    }

    function __setMinPayloadSize(uint256 minPayloadSize) external {
        _getIdentityUpdatesStorage().minPayloadSize = minPayloadSize;
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize) external {
        _getIdentityUpdatesStorage().maxPayloadSize = maxPayloadSize;
    }

    function __getSequenceId() external view returns (uint64) {
        return _getIdentityUpdatesStorage().sequenceId;
    }
}

contract NodeRegistryHarness is NodeRegistry {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address initialAdmin) NodeRegistry(initialAdmin) {}

    function __setNodeCounter(uint256 nodeCounter) external {
        _nodeCounter = uint32(nodeCounter);
    }

    function __addNodeToCanonicalNetwork(uint256 nodeId) external {
        _canonicalNetworkNodes.add(nodeId);
    }

    function __removeNodeFromCanonicalNetwork(uint256 nodeId) external {
        _canonicalNetworkNodes.remove(nodeId);
    }

    function __setMaxActiveNodes(uint8 maxActiveNodes) external {
        _maxActiveNodes = maxActiveNodes;
    }

    function __setNode(
        uint256 nodeId,
        bytes calldata signingKeyPub,
        string calldata httpAddress,
        bool inCanonicalNetwork,
        uint256 minMonthlyFeeMicroDollars
    ) external {
        _nodes[nodeId] = Node(
            signingKeyPub,
            httpAddress,
            inCanonicalNetwork,
            minMonthlyFeeMicroDollars
        );
    }

    function __setApproval(address to, uint256 tokenId, address authorizer) external {
        _approve(to, tokenId, authorizer);
    }

    function __mint(address to, uint256 nodeId) external {
        _mint(to, nodeId);
    }

    function __getNode(uint256 nodeId) external view returns (Node memory node) {
        return _nodes[nodeId];
    }

    function __getOwner(uint256 nodeId) external view returns (address owner) {
        return _ownerOf(nodeId);
    }

    function __getNodeCounter() external view returns (uint32 nodeCounter) {
        return _nodeCounter;
    }

    function __getBaseTokenURI() external view returns (string memory baseTokenURI) {
        return _baseTokenURI;
    }
}

contract RateRegistryHarness is RateRegistry {
    function __pause() external {
        _pause();
    }

    function __unpause() external {
        _unpause();
    }

    function __pushRates(
        uint256 messageFee,
        uint256 storageFee,
        uint256 congestionFee,
        uint256 targetRatePerMinute,
        uint256 startTime
    ) external {
        _getRatesManagerStorage().allRates.push(
            Rates(
                uint64(messageFee),
                uint64(storageFee),
                uint64(congestionFee),
                uint64(targetRatePerMinute),
                uint64(startTime)
            )
        );
    }

    function __getAllRates() external view returns (Rates[] memory) {
        return _getRatesManagerStorage().allRates;
    }
}
