// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC721Upgradeable } from "../../lib/oz-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: Make the rest of the parameters come from the parameter registry.

/**
 * @title  Implementation of the Node Registry
 *
 * @notice This contract is responsible for minting NFTs and assigning them to node owner.
 *         Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 *         In addition to the standard ERC721 functionality, the contract supports node-specific features,
 *         including node property updates.
 *
 * @dev    All nodes on the network periodically check this contract to determine which nodes they should connect to.
 */
contract NodeRegistry is INodeRegistry, Migratable, ERC721Upgradeable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc INodeRegistry
    uint32 public constant NODE_INCREMENT = 100;

    bytes1 internal constant _FORWARD_SLASH = 0x2f;

    /// @inheritdoc INodeRegistry
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.NodeRegistry
     * @notice The UUPS storage for the node registry.
     * @param  baseURI             The base component of the token URI.
     * @param  maxCanonicalNodes   The maximum number of canonical nodes.
     * @param  canonicalNodesCount The current number of canonical nodes.
     * @param  nodeCount           The current number of nodes.
     * @param  nodes               A mapping of node/token IDs to nodes.
     * @param  admin               The admin address.
     */
    struct NodeRegistryStorage {
        string baseURI;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
        mapping(uint32 tokenId => Node node) nodes;
        address admin;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.NodeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _NODE_REGISTRY_STORAGE_LOCATION =
        0xd48713bc7b5e2644bcb4e26ace7d67dc9027725a9a1ee11596536cc6096a2000;

    function _getNodeRegistryStorage() internal pure returns (NodeRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _NODE_REGISTRY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @dev    The parameter registry must not be the zero address.
     * @dev    The parameter registry is immutable so that it is inlined in the contract code, and has minimal gas cost.
     */
    constructor(address parameterRegistry_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistry());
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc INodeRegistry
    function initialize() public initializer {
        __ERC721_init("XMTP Nodes", "nXMTP");

        // TODO: This should probably come from the parameter registry.
        _getNodeRegistryStorage().maxCanonicalNodes = 20;
    }

    /* ============ Admin Functions ============ */

    /// @inheritdoc INodeRegistry
    function addNode(
        address owner_,
        bytes calldata signingPublicKey_,
        string calldata httpAddress_
    ) external onlyAdmin returns (uint32 nodeId_, address signer_) {
        require(owner_ != address(0), InvalidOwner());
        require(signingPublicKey_.length > 0, InvalidSigningPublicKey());
        require(bytes(httpAddress_).length > 0, InvalidHttpAddress());

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        require((uint256($.nodeCount) + 1) * NODE_INCREMENT <= type(uint32).max, MaxNodesReached());

        unchecked {
            nodeId_ = ++$.nodeCount * NODE_INCREMENT; // The first node starts with `nodeId_ = NODE_INCREMENT`.
        }

        signer_ = _toAddress(keccak256(signingPublicKey_));

        // Nodes start off as non-canonical.
        $.nodes[nodeId_] = Node(signer_, false, signingPublicKey_, httpAddress_);

        _mint(owner_, nodeId_);

        emit NodeAdded(nodeId_, owner_, signer_, signingPublicKey_, httpAddress_);
    }

    /// @inheritdoc INodeRegistry
    function addToNetwork(uint32 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        require(!$.nodes[nodeId_].isCanonical, NodeAlreadyInCanonicalNetwork());
        require(++$.canonicalNodesCount <= $.maxCanonicalNodes, MaxCanonicalNodesReached());

        $.nodes[nodeId_].isCanonical = true;

        emit NodeAddedToCanonicalNetwork(nodeId_);
    }

    /// @inheritdoc INodeRegistry
    function removeFromNetwork(uint32 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        require($.nodes[nodeId_].isCanonical, NodeNotInCanonicalNetwork());

        delete $.nodes[nodeId_].isCanonical;
        --$.canonicalNodesCount;

        emit NodeRemovedFromCanonicalNetwork(nodeId_);
    }

    /// @inheritdoc INodeRegistry
    function setMaxCanonicalNodes(uint8 newMaxCanonicalNodes_) external onlyAdmin {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();
        require(newMaxCanonicalNodes_ >= $.canonicalNodesCount, MaxCanonicalNodesBelowCurrentCount());
        emit MaxCanonicalNodesUpdated($.maxCanonicalNodes = newMaxCanonicalNodes_);
    }

    /// @inheritdoc INodeRegistry
    function setBaseURI(string calldata newBaseURI_) external onlyAdmin {
        require(bytes(newBaseURI_).length > 0, InvalidURI());
        require(bytes(newBaseURI_)[bytes(newBaseURI_).length - 1] == _FORWARD_SLASH, InvalidURI());
        emit BaseURIUpdated(_getNodeRegistryStorage().baseURI = newBaseURI_);
    }

    /* ============ Node Owner Functions ============ */

    /// @inheritdoc INodeRegistry
    function setHttpAddress(uint32 nodeId_, string calldata httpAddress_) external {
        _revertIfNotNodeOwner(nodeId_);
        require(bytes(httpAddress_).length > 0, InvalidHttpAddress());
        emit HttpAddressUpdated(nodeId_, _getNodeRegistryStorage().nodes[nodeId_].httpAddress = httpAddress_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc INodeRegistry
    function updateAdmin() external {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        address newAdmin_ = _toAddress(_getRegistryParameter(adminParameterKey()));

        require(newAdmin_ != $.admin, NoChange());

        emit AdminUpdated($.admin = newAdmin_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc INodeRegistry
    function admin() external view returns (address admin_) {
        return _getNodeRegistryStorage().admin;
    }

    /// @inheritdoc INodeRegistry
    function adminParameterKey() public pure returns (bytes memory key_) {
        return bytes("xmtp.nodeRegistry.admin");
    }

    /// @inheritdoc INodeRegistry
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return bytes("xmtp.nodeRegistry.migrator");
    }

    /// @inheritdoc INodeRegistry
    function maxCanonicalNodes() external view returns (uint8 maxCanonicalNodes_) {
        return _getNodeRegistryStorage().maxCanonicalNodes;
    }

    /// @inheritdoc INodeRegistry
    function canonicalNodesCount() external view returns (uint8 canonicalNodesCount_) {
        return _getNodeRegistryStorage().canonicalNodesCount;
    }

    /// @inheritdoc INodeRegistry
    function getAllNodes() external view returns (NodeWithId[] memory allNodes_) {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        allNodes_ = new NodeWithId[]($.nodeCount);

        for (uint32 index_; index_ < $.nodeCount; ++index_) {
            uint32 nodeId_ = NODE_INCREMENT * (index_ + 1);
            allNodes_[index_] = NodeWithId({ nodeId: nodeId_, node: $.nodes[nodeId_] });
        }
    }

    /// @inheritdoc INodeRegistry
    function getAllNodesCount() external view returns (uint32 nodeCount_) {
        return _getNodeRegistryStorage().nodeCount;
    }

    /// @inheritdoc INodeRegistry
    function getNode(uint32 nodeId_) external view returns (Node memory node_) {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.
        return _getNodeRegistryStorage().nodes[nodeId_];
    }

    /// @inheritdoc INodeRegistry
    function getIsCanonicalNode(uint32 nodeId_) external view returns (bool isCanonicalNode_) {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.
        return _getNodeRegistryStorage().nodes[nodeId_].isCanonical;
    }

    /// @inheritdoc INodeRegistry
    function getSigner(uint32 nodeId_) external view returns (address signer_) {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.
        return _getNodeRegistryStorage().nodes[nodeId_].signer;
    }

    /* ============ Internal View/Pure Functions ============ */

    function _baseURI() internal view override returns (string memory baseURI_) {
        return _getNodeRegistryStorage().baseURI;
    }

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }

    function _revertIfNotAdmin() internal view {
        require(msg.sender == _getNodeRegistryStorage().admin, NotAdmin());
    }

    function _revertIfNotNodeOwner(uint32 nodeId_) internal view {
        require(_requireOwned(nodeId_) == msg.sender, NotNodeOwner());
    }
}
