// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "../../../lib/oz/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "../../../lib/oz/contracts/interfaces/draft-IERC6093.sol";
import { IERC721Metadata } from "../../../lib/oz/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IVersioned } from "../../abstract/interfaces/IVersioned.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for the Node Registry.
 * @notice This interface defines the ERC721-based registry for “nodes” in the system.
 *         Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 *         In addition to the standard ERC721 functionality, the contract supports node-specific features, including
 *         node property updates.
 */
interface INodeRegistry is IERC721, IERC721Metadata, IERC721Errors, IMigratable, IVersioned, IRegistryParametersErrors {
    /* ============ Structs ============ */

    /**
     * @notice Struct representing a node in the registry.
     * @param  signer           The address derived by the signing public key, for convenience.
     * @param  isCanonical      A flag indicating whether the node is part of the canonical network.
     * @param  signingPublicKey The public key used for node signing/verification.
     * @param  httpAddress      The HTTP endpoint address for the node.
     */
    struct Node {
        address signer;
        bool isCanonical;
        bytes signingPublicKey;
        string httpAddress;
    }

    /**
     * @notice Struct representing a node with its ID.
     * @param  nodeId The unique identifier for the node.
     * @param  node   The node struct.
     */
    struct NodeWithId {
        uint32 nodeId;
        Node node;
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when the admin is updated.
     * @param  admin The new admin.
     */
    event AdminUpdated(address indexed admin);

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
    event HttpAddressUpdated(uint32 indexed nodeId, string httpAddress);

    /**
     * @notice Emitted when the maximum number of canonical nodes is updated.
     * @param  maxCanonicalNodes The new maximum number of canonical nodes.
     */
    event MaxCanonicalNodesUpdated(uint8 maxCanonicalNodes);

    /**
     * @notice Emitted when a new node is added and its NFT minted.
     * @param  nodeId           The unique identifier for the node (starts at 100, increments by 100).
     * @param  owner            The address that receives the new node NFT.
     * @param  signer           The address derived by the signing public key, for convenience.
     * @param  signingPublicKey The public key used for node signing/verification.
     * @param  httpAddress      The node’s HTTP endpoint.
     */
    event NodeAdded(
        uint32 indexed nodeId,
        address indexed owner,
        address indexed signer,
        bytes signingPublicKey,
        string httpAddress
    );

    /**
     * @notice Emitted when a node is added to the canonical network.
     * @param  nodeId The identifier of the node.
     */
    event NodeAddedToCanonicalNetwork(uint32 indexed nodeId);

    /**
     * @notice Emitted when a node is removed from the canonical network.
     * @param  nodeId The identifier of the node.
     */
    event NodeRemovedFromCanonicalNetwork(uint32 indexed nodeId);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when failing to add a node to the canonical network.
    error FailedToAddNodeToCanonicalNetwork();

    /// @notice Thrown when failing to remove a node from the canonical network.
    error FailedToRemoveNodeFromCanonicalNetwork();

    /// @notice Thrown when an invalid owner is provided.
    error InvalidOwner();

    /// @notice Thrown when an invalid HTTP address is provided.
    error InvalidHttpAddress();

    /// @notice Thrown when an invalid signing public key is provided.
    error InvalidSigningPublicKey();

    /// @notice Thrown when an invalid URI is provided.
    error InvalidURI();

    /// @notice Thrown when trying to set max canonical nodes below current canonical count.
    error MaxCanonicalNodesBelowCurrentCount();

    /// @notice Thrown when the maximum number of canonical nodes is reached.
    error MaxCanonicalNodesReached();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when the caller is not the admin.
    error NotAdmin();

    /// @notice Thrown when the maximum number of nodes is reached.
    error MaxNodesReached();

    /// @notice Thrown when the caller is not the node owner.
    error NotNodeOwner();

    /// @notice Thrown when the admin is the zero address.
    error ZeroAdmin();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Admin Functions ============ */

    /**
     * @notice Adds a new node to the registry and mints its corresponding ERC721 token.
     * @param  owner_            The address that will own the new node node/NFT.
     * @param  signingPublicKey_ The public key used for node signing/verification.
     * @param  httpAddress_      The node’s HTTP address.
     * @return nodeId_           The unique identifier of the newly added node.
     * @return signer_           The address derived by the signing public key, for convenience.
     * @dev    Node IDs start at 100 and increase by 100 for each new node.
     */
    function addNode(
        address owner_,
        bytes calldata signingPublicKey_,
        string calldata httpAddress_
    ) external returns (uint32 nodeId_, address signer_);

    /**
     * @notice Adds a node to the canonical network.
     * @param  nodeId_ The unique identifier of the node.
     */
    function addToNetwork(uint32 nodeId_) external;

    /**
     * @notice Removes a node from the canonical network.
     * @param  nodeId_ The unique identifier of the node.
     */
    function removeFromNetwork(uint32 nodeId_) external;

    /**
     * @notice Set the base URI for the node NFTs.
     * @param  baseURI_ The new base URI. Has to end with a trailing slash.
     */
    function setBaseURI(string calldata baseURI_) external;

    /* ============ Node Owner Functions ============ */

    /**
     * @notice Set the HTTP address of an existing node.
     * @param  nodeId_      The unique identifier of the node.
     * @param  httpAddress_ The new HTTP address.
     */
    function setHttpAddress(uint32 nodeId_, string calldata httpAddress_) external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Updates the admin by referring to the admin parameter from the parameter registry.
     */
    function updateAdmin() external;

    /**
     * @notice Updates the max canonical nodes by referring to the max canonical nodes parameter from the parameter
     *         registry.
     */
    function updateMaxCanonicalNodes() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The increment for node IDs, which allows for 100 shard node IDs per node in the future (modulus 100).
    // slither-disable-next-line naming-convention
    function NODE_INCREMENT() external pure returns (uint32 nodeIncrement_);

    /// @notice Returns semver version string.
    function version() external pure returns (string memory version_);

    /// @notice The address of the admin.
    function admin() external view returns (address admin_);

    /// @notice The parameter registry key used to fetch the admin.
    function adminParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the max canonical nodes.
    function maxCanonicalNodesParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The maximum number of nodes that can be part of the canonical network.
    function maxCanonicalNodes() external view returns (uint8 maxCanonicalNodes_);

    /// @notice The number of nodes that are part of the canonical network.
    function canonicalNodesCount() external view returns (uint8 canonicalNodesCount_);

    /**
     * @notice Gets all nodes regardless of their health status.
     * @return allNodes_ An array of all nodes in the registry.
     */
    function getAllNodes() external view returns (NodeWithId[] memory allNodes_);

    /**
     * @notice Gets the total number of nodes in the registry.
     * @return nodeCount_ The total number of nodes.
     */
    function getAllNodesCount() external view returns (uint32 nodeCount_);

    /**
     * @notice Gets all canonical nodes IDs.
     * @return canonicalNodes_ An array of all canonical nodes.
     */
    function getCanonicalNodes() external view returns (uint32[] memory canonicalNodes_);

    /**
     * @notice Retrieves the details of a given node.
     * @param  nodeId_ The unique identifier of the node.
     * @return node_   The Node struct containing the node's details.
     */
    function getNode(uint32 nodeId_) external view returns (Node memory node_);

    /**
     * @notice Retrieves whether a node is part of the canonical network.
     * @param  nodeId_          The unique identifier of the node.
     * @return isCanonicalNode_ A boolean indicating whether the node is part of the canonical network.
     */
    function getIsCanonicalNode(uint32 nodeId_) external view returns (bool isCanonicalNode_);

    /**
     * @notice Retrieves the signer of a node.
     * @param  nodeId_ The unique identifier of the node.
     * @return signer_ The address of the signer.
     */
    function getSigner(uint32 nodeId_) external view returns (address signer_);
}
