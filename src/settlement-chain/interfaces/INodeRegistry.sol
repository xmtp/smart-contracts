// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Import the standard ERC721 interface.
import { IERC721 } from "../../../lib/oz/contracts/token/ERC721/IERC721.sol";

/**
 * @title  INodeRegistryErrors
 * @notice This interface defines the errors emitted by the INodes contract.
 */
interface INodeRegistryErrors {
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

    /// @notice Error thrownwhen trying to set max active nodes below current active count.
    error MaxActiveNodesBelowCurrentCount();

    /// @notice Error thrown when the maximum number of active nodes is reached.
    error MaxActiveNodesReached();

    /// @notice Error thrown when a node does not exist.
    error NodeDoesNotExist();
}

/**
 * @title  INodeRegistryEvents
 * @notice This interface defines the events emitted by the INodes contract.
 */
interface INodeRegistryEvents {
    /**
     * @notice Emitted when the base URI is updated.
     * @param  newBaseURI The new base URI.
     */
    event BaseURIUpdated(string newBaseURI);

    /**
     * @notice Emitted when the HTTP address for a node is updated.
     * @param  nodeId         The identifier of the node.
     * @param  newHttpAddress The new HTTP address.
     */
    event HttpAddressUpdated(uint256 indexed nodeId, string newHttpAddress);

    /**
     * @notice Emitted when the maximum number of active nodes is updated.
     * @param  newMaxActiveNodes The new maximum number of active nodes.
     */
    event MaxActiveNodesUpdated(uint8 newMaxActiveNodes);

    /**
     * @notice Emitted when the minimum monthly fee for a node is updated.
     * @param  nodeId                    The identifier of the node.
     * @param  minMonthlyFeeMicroDollars The updated minimum fee.
     */
    event MinMonthlyFeeUpdated(uint256 indexed nodeId, uint256 minMonthlyFeeMicroDollars);

    /**
     * @notice Emitted when a new node is added and its NFT minted.
     * @param  nodeId                    The unique identifier for the node (starts at 100, increments by 100).
     * @param  owner                     The address that receives the new node NFT.
     * @param  signingKeyPub             The node’s signing key public value.
     * @param  httpAddress               The node’s HTTP endpoint.
     * @param  minMonthlyFeeMicroDollars The minimum monthly fee for the node.
     */
    event NodeAdded(
        uint256 indexed nodeId,
        address indexed owner,
        bytes signingKeyPub,
        string httpAddress,
        uint256 minMonthlyFeeMicroDollars
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
     * @param  newCommissionPercent The new commission percentage.
     */
    event NodeOperatorCommissionPercentUpdated(uint256 newCommissionPercent);
}

/**
 * @title  INodeRegistry
 * @notice This interface defines the ERC721-based registry for “nodes” in the system.
 * Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 * In addition to the standard ERC721 functionality, the contract supports node-specific features,
 * including node property updates.
 */
interface INodeRegistry is INodeRegistryErrors, INodeRegistryEvents, IERC721 {
    /**
     * @notice Struct representing a node in the registry.
     * @param  signingKeyPub      The public key used for node signing/verification.
     * @param  httpAddress        The HTTP endpoint address for the node.
     * @param  inCanonicalNetwork A flag indicating whether the node is part of the canonical network.
     * @param  minMonthlyFee      The minimum monthly fee collected by the node operator.
     */
    struct Node {
        bytes signingKeyPub;
        string httpAddress;
        bool inCanonicalNetwork;
        uint256 minMonthlyFeeMicroDollars;
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

    /* ============ Admin-Only Functions ============ */

    /**
     * @notice Adds a new node to the registry and mints its corresponding ERC721 token.
     * @dev    Only the contract owner may call this. Node IDs start at 100 and increase by 100 for each new node.
     * @param  to                        The address that will own the new node NFT.
     * @param  signingKeyPub             The public signing key for the node.
     * @param  httpAddress               The node’s HTTP address.
     * @param  minMonthlyFeeMicroDollars The minimum monthly fee that the node operator collects.
     * @return nodeId                    The unique identifier of the newly added node.
     */
    function addNode(
        address to,
        bytes calldata signingKeyPub,
        string calldata httpAddress,
        uint256 minMonthlyFeeMicroDollars
    ) external returns (uint256 nodeId);

    /**
     * @notice Adds a node to the canonical network.
     * @dev    Only the contract owner may call this.
     * @param  nodeId The unique identifier of the node.
     */
    function addToNetwork(uint256 nodeId) external;

    /**
     * @notice Removes a node from the canonical network.
     * @dev    Only the contract owner may call this.
     * @param  nodeId The unique identifier of the node.
     */
    function removeFromNetwork(uint256 nodeId) external;

    /**
     * @notice Sets the commission percentage that the node operator receives.
     * @dev    Only the contract owner may call this.
     * @param  newCommissionPercent The new commission percentage.
     */
    function setNodeOperatorCommissionPercent(uint256 newCommissionPercent) external;

    /**
     * @notice Sets the maximum number of active nodes.
     * @dev    Only the contract owner may call this.
     * @param  newMaxActiveNodes The new maximum number of active nodes.
     */
    function setMaxActiveNodes(uint8 newMaxActiveNodes) external;

    /**
     * @notice Set the base URI for the node NFTs.
     * @dev    Only the contract owner may call this.
     * @param  newBaseURI The new base URI. Has to end with a trailing slash.
     */
    function setBaseURI(string calldata newBaseURI) external;

    /* ============ Node Manager Functions ============ */

    /**
     * @notice Transfers node ownership from one address to another.
     * @dev    Only the contract owner may call this. Automatically deactivates the node.
     * @param  from   The current owner address.
     * @param  to     The new owner address.
     * @param  nodeId The ID of the node being transferred.
     */
    function transferFrom(address from, address to, uint256 nodeId) external;

    /**
     * @notice Set the HTTP address of an existing node.
     * @dev    Only the contract owner may call this.
     * @param  nodeId      The unique identifier of the node.
     * @param  httpAddress The new HTTP address.
     */
    function setHttpAddress(uint256 nodeId, string calldata httpAddress) external;

    /**
     * @notice Set the minimum monthly fee for a node.
     * @dev    Only the contract owner may call this.
     * @param  nodeId                    The unique identifier of the node.
     * @param  minMonthlyFeeMicroDollars The new minimum monthly fee.
     */
    function setMinMonthlyFee(uint256 nodeId, uint256 minMonthlyFeeMicroDollars) external;

    /* ============ Getters Functions ============ */

    /// @notice The admin role identifier, which can also grant roles.
    // slither-disable-next-line naming-convention
    function ADMIN_ROLE() external pure returns (bytes32 adminRole);

    /// @notice The node manager role identifier.
    // slither-disable-next-line naming-convention
    function NODE_MANAGER_ROLE() external pure returns (bytes32 nodeManagerRole);

    /// @notice The maximum commission percentage that the node operator can receive (100% in basis points).
    // slither-disable-next-line naming-convention
    function MAX_BPS() external pure returns (uint256 maxBps);

    /// @notice The increment for node IDs, which allows for 100 shard node IDs per node in the future (modulus 100).
    // slither-disable-next-line naming-convention
    function NODE_INCREMENT() external pure returns (uint32 nodeIncrement);

    /// @notice The maximum number of nodes that can be part of the canonical network.
    function maxActiveNodes() external view returns (uint8 max);

    /// @notice The commission percentage that the node operator receives.
    function nodeOperatorCommissionPercent() external view returns (uint256 commissionPercent);

    /**
     * @notice Gets all nodes regardless of their health status.
     * @return allNodes An array of all nodes in the registry.
     */
    function getAllNodes() external view returns (NodeWithId[] memory allNodes);

    /**
     * @notice Gets the total number of nodes in the registry.
     * @return nodeCount The total number of nodes.
     */
    function getAllNodesCount() external view returns (uint256 nodeCount);

    /**
     * @notice Retrieves the details of a given node.
     * @param  nodeId The unique identifier of the node.
     * @return node   The Node struct containing the node's details.
     */
    function getNode(uint256 nodeId) external view returns (Node memory node);

    /**
     * @notice Retrieves whether a node is part of the canonical network.
     * @param  nodeId The unique identifier of the node.
     * @return isCanonicalNode A boolean indicating whether the node is part of the canonical network.
     */
    function getIsCanonicalNode(uint256 nodeId) external view returns (bool isCanonicalNode);
}
