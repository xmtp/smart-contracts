// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "../../../lib/oz/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "../../../lib/oz/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Errors } from "../../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

/**
 * @title  INodeRegistry
 * @notice This interface defines the ERC721-based registry for “nodes” in the system.
 *         Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 *         In addition to the standard ERC721 functionality, the contract supports node-specific features, including
 *         node property updates.
 */
interface INodeRegistry is IERC721, IERC721Metadata, IERC721Errors, IMigratable {
    /* ============ Structs ============ */

    /**
     * @notice Struct representing a node in the registry.
     * @param  signingKeyPub The public key used for node signing/verification.
     * @param  httpAddress   The HTTP endpoint address for the node.
     * @param  isCanonical   A flag indicating whether the node is part of the canonical network.
     * @param  minMonthlyFee The minimum monthly fee collected by the node operator.
     */
    struct Node {
        bytes signingKeyPub;
        string httpAddress;
        bool isCanonical;
        uint256 minMonthlyFee;
    }

    /**
     * @notice Struct representing a node with its ID.
     * @param  nodeId The unique identifier for the node.
     * @param  node   The node struct.
     */
    struct NodeWithId {
        uint256 nodeId;
        Node node;
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when the admin is updated.
     * @param  admin The new admin.
     */
    event AdminUpdated(address indexed admin);

    /**
     * @notice Emitted when the node manager is updated.
     * @param  nodeManager The new node manager.
     */
    event NodeManagerUpdated(address indexed nodeManager);

    /**
     * @notice Emitted when the base URI is updated.
     * @param  baseURI The new base URI.
     */
    event BaseURIUpdated(string baseURI);

    /**
     * @notice Emitted when the HTTP address for a node is updated.
     * @param  nodeId      The identifier of the node.
     * @param  httpAddress The new HTTP address.
     */
    event HttpAddressUpdated(uint256 indexed nodeId, string httpAddress);

    /**
     * @notice Emitted when the maximum number of canonical nodes is updated.
     * @param  maxCanonicalNodes The new maximum number of canonical nodes.
     */
    event MaxCanonicalNodesUpdated(uint8 maxCanonicalNodes);

    /**
     * @notice Emitted when the minimum monthly fee for a node is updated.
     * @param  nodeId        The identifier of the node.
     * @param  minMonthlyFee The updated minimum fee.
     */
    event MinMonthlyFeeUpdated(uint256 indexed nodeId, uint256 minMonthlyFee);

    /**
     * @notice Emitted when a new node is added and its NFT minted.
     * @param  nodeId        The unique identifier for the node (starts at 100, increments by 100).
     * @param  owner         The address that receives the new node NFT.
     * @param  signingKeyPub The node’s signing key public value.
     * @param  httpAddress   The node’s HTTP endpoint.
     * @param  minMonthlyFee The minimum monthly fee for the node.
     */
    event NodeAdded(
        uint256 indexed nodeId,
        address indexed owner,
        bytes signingKeyPub,
        string httpAddress,
        uint256 minMonthlyFee
    );

    /**
     * @notice Emitted when a node is added to the canonical network.
     * @param  nodeId The identifier of the node.
     */
    event NodeAddedToCanonicalNetwork(uint256 indexed nodeId);

    /**
     * @notice Emitted when a node is removed from the canonical network.
     * @param  nodeId The identifier of the node.
     */
    event NodeRemovedFromCanonicalNetwork(uint256 indexed nodeId);

    /**
     * @notice Emitted when the node operator commission percent is updated.
     * @param  commissionPercent The new commission percentage.
     */
    event NodeOperatorCommissionPercentUpdated(uint256 commissionPercent);

    /* ============ Custom Errors ============ */

    /// @notice Error thrown when the parameter registry address is being set to 0x0.
    error ZeroParameterRegistryAddress();

    /// @notice Error thrown when failing to add a node to the canonical network.
    error FailedToAddNodeToCanonicalNetwork();

    /// @notice Error thrown when failing to remove a node from the canonical network.
    error FailedToRemoveNodeFromCanonicalNetwork();

    /// @notice Error thrown when an invalid address is provided.
    error InvalidAddress();

    /// @notice Error thrown when an invalid commission percentage is provided.
    error InvalidCommissionPercent();

    /// @notice Error thrown when an invalid HTTP address is provided.
    error InvalidHttpAddress();

    /// @notice Error thrown when an invalid signing key is provided.
    error InvalidSigningKey();

    /// @notice Error thrown when an invalid URI is provided.
    error InvalidURI();

    /// @notice Error thrown when trying to set max canonical nodes below current canonical count.
    error MaxCanonicalNodesBelowCurrentCount();

    /// @notice Error thrown when the maximum number of canonical nodes is reached.
    error MaxCanonicalNodesReached();

    /// @notice Error thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Error thrown when the caller is not the admin.
    error NotAdmin();

    /// @notice Error thrown when the caller is not the node manager.
    error NotNodeManager();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Admin Functions ============ */

    /**
     * @notice Adds a new node to the registry and mints its corresponding ERC721 token.
     * @dev    Node IDs start at 100 and increase by 100 for each new node.
     * @param  to_            The address that will own the new node NFT.
     * @param  signingKeyPub_ The public signing key for the node.
     * @param  httpAddress_   The node’s HTTP address.
     * @param  minMonthlyFee_ The minimum monthly fee that the node operator collects.
     * @return nodeId_        The unique identifier of the newly added node.
     */
    function addNode(
        address to_,
        bytes calldata signingKeyPub_,
        string calldata httpAddress_,
        uint256 minMonthlyFee_
    ) external returns (uint256 nodeId_);

    /**
     * @notice Adds a node to the canonical network.
     * @param  nodeId_ The unique identifier of the node.
     */
    function addToNetwork(uint256 nodeId_) external;

    /**
     * @notice Removes a node from the canonical network.
     * @param  nodeId_ The unique identifier of the node.
     */
    function removeFromNetwork(uint256 nodeId_) external;

    /**
     * @notice Sets the commission percentage that the node operator receives.
     * @param  newCommissionPercent_ The new commission percentage.
     */
    function setNodeOperatorCommissionPercent(uint16 newCommissionPercent_) external;

    /**
     * @notice Sets the maximum number of canonical nodes.
     * @param  newMaxCanonicalNodes_ The new maximum number of canonical nodes.
     */
    function setMaxCanonicalNodes(uint8 newMaxCanonicalNodes_) external;

    /**
     * @notice Set the base URI for the node NFTs.
     * @param  newBaseURI_ The new base URI. Has to end with a trailing slash.
     */
    function setBaseURI(string calldata newBaseURI_) external;

    /* ============ Node Manager Functions ============ */

    /**
     * @notice Set the HTTP address of an existing node.
     * @param  nodeId_      The unique identifier of the node.
     * @param  httpAddress_ The new HTTP address.
     */
    function setHttpAddress(uint256 nodeId_, string calldata httpAddress_) external;

    /**
     * @notice Set the minimum monthly fee for a node.
     * @param  nodeId_        The unique identifier of the node.
     * @param  minMonthlyFee_ The new minimum monthly fee.
     */
    function setMinMonthlyFee(uint256 nodeId_, uint256 minMonthlyFee_) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Updates the admin by referring to the last admin parameter from the parameter registry.
     */
    function updateAdmin() external;

    /**
     * @notice Updates the node manager by referring to the last node manager parameter from the parameter registry.
     */
    function updateNodeManager() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The maximum commission percentage that the node operator can receive (100% in basis points).
    // slither-disable-next-line naming-convention
    function MAX_BPS() external pure returns (uint16 maxBps_);

    /// @notice The increment for node IDs, which allows for 100 shard node IDs per node in the future (modulus 100).
    // slither-disable-next-line naming-convention
    function NODE_INCREMENT() external pure returns (uint32 nodeIncrement_);

    /// @notice The address of the admin.
    function admin() external view returns (address admin_);

    /// @notice The address of the node manager.
    function nodeManager() external view returns (address nodeManager_);

    /// @notice The parameter registry key of the admin parameter.
    function adminParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key of the node manager parameter.
    function nodeManagerParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The maximum number of nodes that can be part of the canonical network.
    function maxCanonicalNodes() external view returns (uint8 maxCanonicalNodes_);

    /// @notice The number of nodes that are part of the canonical network.
    function canonicalNodesCount() external view returns (uint8 canonicalNodesCount_);

    /// @notice The commission percentage that the node operator receives.
    function nodeOperatorCommissionPercent() external view returns (uint16 commissionPercent_);

    /**
     * @notice Gets all nodes regardless of their health status.
     * @return allNodes_ An array of all nodes in the registry.
     */
    function getAllNodes() external view returns (NodeWithId[] memory allNodes_);

    /**
     * @notice Gets the total number of nodes in the registry.
     * @return nodeCount_ The total number of nodes.
     */
    function getAllNodesCount() external view returns (uint256 nodeCount_);

    /**
     * @notice Retrieves the details of a given node.
     * @param  nodeId_ The unique identifier of the node.
     * @return node_   The Node struct containing the node's details.
     */
    function getNode(uint256 nodeId_) external view returns (Node memory node_);

    /**
     * @notice Retrieves whether a node is part of the canonical network.
     * @param  nodeId_ The unique identifier of the node.
     * @return isCanonicalNode_ A boolean indicating whether the node is part of the canonical network.
     */
    function getIsCanonicalNode(uint256 nodeId_) external view returns (bool isCanonicalNode_);
}
