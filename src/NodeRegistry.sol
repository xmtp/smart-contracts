// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC165 } from "../lib/oz/contracts/utils/introspection/IERC165.sol";
import { ERC721 } from "../lib/oz/contracts/token/ERC721/ERC721.sol";
import {AccessControlDefaultAdminRules} from "../lib/oz/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { EnumerableSet } from "../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

/**
 * @title XMTP Nodes Registry
 *
 * @notice This contract is responsible for minting NFTs and assigning them to node operators.
 * Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 * In addition to the standard ERC721 functionality, the contract supports node-specific features,
 * including node property updates.
 *
 * @dev All nodes on the network periodically check this contract to determine which nodes they should connect to.
 * The contract owner is responsible for:
 *   - minting and transferring NFTs to node operators.
 *   - updating the node operator's HTTP address and MTLS certificate.
 *   - updating the node operator's minimum monthly fee.
 *   - updating the node operator's API enabled flag.
 */
contract NodeRegistry is INodeRegistry, AccessControlDefaultAdminRules, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc INodeRegistry
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @inheritdoc INodeRegistry
    bytes32 public constant NODE_MANAGER_ROLE = keccak256("NODE_MANAGER_ROLE");

    /// @inheritdoc INodeRegistry
    uint256 public constant MAX_BPS = 10_000;

    /// @inheritdoc INodeRegistry
    uint32 public constant NODE_INCREMENT = 100;

    uint48 internal constant _INITIAL_ACCESS_CONTROL_DELAY = 2 days;

    bytes1 internal constant _FORWARD_SLASH = 0x2f;

    /// @dev The base URI for the node NFTs.
    string internal _baseTokenURI;

    /// @dev The maximum number of nodes in the canonical network.
    uint8 internal _maxActiveNodes = 20;

    /**
     * @dev The counter for n max IDs.
     * The ERC721 standard expects the tokenID to be uint256 for standard methods unfortunately.
     */
    uint32 internal _nodeCounter = 0;

    /// @dev Mapping of token ID to Node.
    mapping(uint256 => Node) internal _nodes;

    /// @dev Nodes part of the canonical network.
    EnumerableSet.UintSet internal _canonicalNetworkNodes;

    /// @dev The commission percentage that the node operator receives.
    uint256 public nodeOperatorCommissionPercent;

    constructor(
        address initialAdmin
    ) ERC721("XMTP Node Operator", "XMTP") AccessControlDefaultAdminRules(_INITIAL_ACCESS_CONTROL_DELAY, initialAdmin) {
        require(initialAdmin != address(0), InvalidAddress());

        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(NODE_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        // slither-disable-next-line unused-return
        _grantRole(ADMIN_ROLE, initialAdmin); // Will return false if the role is already granted.

        // slither-disable-next-line unused-return
        _grantRole(NODE_MANAGER_ROLE, initialAdmin); // Will return false if the role is already granted.
    }

    /* ============ Admin-Only Functions ============ */

    /**
     * @inheritdoc INodeRegistry
     */
    function addNode(
        address to,
        bytes calldata signingKeyPub,
        string calldata httpAddress,
        uint256 minMonthlyFeeMicroDollars
    ) external onlyRole(ADMIN_ROLE) returns (uint256 nodeId) {
        require(to != address(0), InvalidAddress());
        require(signingKeyPub.length > 0, InvalidSigningKey());
        require(bytes(httpAddress).length > 0, InvalidHttpAddress());

        nodeId = ++_nodeCounter * NODE_INCREMENT; // The first node starts with `nodeId = NODE_INCREMENT`.

        _nodes[nodeId] = Node(signingKeyPub, httpAddress, false, minMonthlyFeeMicroDollars);

        _mint(to, nodeId);

        emit NodeAdded(nodeId, to, signingKeyPub, httpAddress, minMonthlyFeeMicroDollars);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function addToNetwork(uint256 nodeId) external onlyRole(ADMIN_ROLE) {
        _revertIfNodeDoesNotExist(nodeId);

        require(_canonicalNetworkNodes.length() < _maxActiveNodes, MaxActiveNodesReached());
        require(!_canonicalNetworkNodes.contains(nodeId), NodeAlreadyInCanonicalNetwork());

        require(_canonicalNetworkNodes.add(nodeId), FailedToAddNodeToCanonicalNetwork());

        _nodes[nodeId].inCanonicalNetwork = true;

        emit NodeEnabled(nodeId);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function removeFromNetwork(uint256 nodeId) external onlyRole(ADMIN_ROLE) {
        _revertIfNodeDoesNotExist(nodeId);

        require(_canonicalNetworkNodes.contains(nodeId), NodeNotInCanonicalNetwork());

        require(_canonicalNetworkNodes.remove(nodeId), FailedToRemoveNodeFromCanonicalNetwork());

        _nodes[nodeId].inCanonicalNetwork = false;

        emit NodeDisabled(nodeId);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function setMaxActiveNodes(uint8 newMaxActiveNodes) external onlyRole(ADMIN_ROLE) {
        require(newMaxActiveNodes >= _canonicalNetworkNodes.length(), MaxActiveNodesBelowCurrentCount());
        _maxActiveNodes = newMaxActiveNodes;
        emit MaxActiveNodesUpdated(newMaxActiveNodes);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function setNodeOperatorCommissionPercent(uint256 newCommissionPercent) external onlyRole(ADMIN_ROLE) {
        require(newCommissionPercent <= MAX_BPS, InvalidCommissionPercent());
        nodeOperatorCommissionPercent = newCommissionPercent;
        emit NodeOperatorCommissionPercentUpdated(newCommissionPercent);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function setBaseURI(string calldata newBaseURI) external onlyRole(ADMIN_ROLE) {
        require(bytes(newBaseURI).length > 0, InvalidURI());
        require(bytes(newBaseURI)[bytes(newBaseURI).length - 1] == _FORWARD_SLASH, InvalidURI());
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /* ============ Node Manager Functions ============ */

    /**
     * @inheritdoc INodeRegistry
     */
    function transferFrom(
        address from,
        address to,
        uint256 nodeId
    ) public override(INodeRegistry, ERC721) onlyRole(NODE_MANAGER_ROLE) {
        super.transferFrom(from, to, nodeId);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function setHttpAddress(uint256 nodeId, string calldata httpAddress) external onlyRole(NODE_MANAGER_ROLE) {
        _revertIfNodeDoesNotExist(nodeId);
        require(bytes(httpAddress).length > 0, InvalidHttpAddress());
        _nodes[nodeId].httpAddress = httpAddress;
        emit HttpAddressUpdated(nodeId, httpAddress);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function setMinMonthlyFee(uint256 nodeId, uint256 minMonthlyFeeMicroDollars) external onlyRole(NODE_MANAGER_ROLE) {
        _revertIfNodeDoesNotExist(nodeId);
        _nodes[nodeId].minMonthlyFeeMicroDollars = minMonthlyFeeMicroDollars;
        emit MinMonthlyFeeUpdated(nodeId, minMonthlyFeeMicroDollars);
    }

    /* ============ Getters ============ */

    /**
     * @inheritdoc INodeRegistry
     */
    function getAllNodes() public view returns (NodeWithId[] memory allNodes) {
        allNodes = new NodeWithId[](_nodeCounter);

        for (uint32 i; i < _nodeCounter; ++i) {
            uint32 nodeId = NODE_INCREMENT * (i + 1);

            allNodes[i] = NodeWithId({ nodeId: nodeId, node: _nodes[nodeId] });
        }
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function getAllNodesCount() public view returns (uint256 nodeCount) {
        return _nodeCounter;
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function getNode(uint256 nodeId) public view returns (Node memory node) {
        _revertIfNodeDoesNotExist(nodeId);
        return _nodes[nodeId];
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function getIsCanonicalNode(uint256 nodeId) external view returns (bool isCanonicalNode) {
        return _canonicalNetworkNodes.contains(nodeId);
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function getMaxActiveNodes() external view returns (uint8 maxNodes) {
        return _maxActiveNodes;
    }

    /**
     * @inheritdoc INodeRegistry
     */
    function getNodeOperatorCommissionPercent() external view returns (uint256 commissionPercent) {
        return nodeOperatorCommissionPercent;
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev    Checks if a node exists.
     * @param  nodeId The ID of the node to check.
     * @return exists True if the node exists, false otherwise.
     */
    function _nodeExists(uint256 nodeId) internal view returns (bool exists) {
        return _ownerOf(nodeId) != address(0);
    }

    /**
     * @inheritdoc ERC721
     */
    function _baseURI() internal view virtual override returns (string memory baseURI) {
        return _baseTokenURI;
    }

    /**
     * @dev Override to support INodeRegistry, ERC721, IERC165, and AccessControlEnumerable.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, IERC165, AccessControlDefaultAdminRules) returns (bool supported) {
        return interfaceId == type(INodeRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Reverts if the node does not exist.
    function _revertIfNodeDoesNotExist(uint256 nodeId) internal view {
        require(_nodeExists(nodeId), NodeDoesNotExist());
    }
}
