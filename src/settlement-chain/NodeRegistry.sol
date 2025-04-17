// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC721Upgradeable } from "../../lib/oz-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: `nodeOperatorCommissionPercent` (and thus `MAX_BPS`) likely does not belong in this contract.

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
contract NodeRegistry is INodeRegistry, Migratable, ERC721Upgradeable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc INodeRegistry
    uint16 public constant MAX_BPS = 10_000;

    /// @inheritdoc INodeRegistry
    uint32 public constant NODE_INCREMENT = 100;

    bytes1 internal constant _FORWARD_SLASH = 0x2f;

    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.NodeRegistry
    struct NodeRegistryStorage {
        string baseURI;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
        uint16 nodeOperatorCommissionPercent;
        mapping(uint256 tokenId => Node node) nodes;
        address admin;
        address nodeManager;
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

    modifier onlyNodeManager() {
        _revertIfNotNodeManager();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the NodeRegistry contract.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc INodeRegistry
    function initialize() public initializer {
        __ERC721_init("XMTP Node Operator", "XMTP");

        // TODO: This should probably come from the parameter registry.
        _getNodeRegistryStorage().maxCanonicalNodes = 20;
    }

    /* ============ Admin-Only Functions ============ */

    /// @inheritdoc INodeRegistry
    function addNode(
        address to_,
        bytes calldata signingKeyPub_,
        string calldata httpAddress_,
        uint256 minMonthlyFee_
    ) external onlyAdmin returns (uint256 nodeId_) {
        require(to_ != address(0), InvalidAddress());
        require(signingKeyPub_.length > 0, InvalidSigningKey());
        require(bytes(httpAddress_).length > 0, InvalidHttpAddress());

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        nodeId_ = uint256(++$.nodeCount) * NODE_INCREMENT; // The first node starts with `nodeId_ = NODE_INCREMENT`.

        $.nodes[nodeId_] = Node(signingKeyPub_, httpAddress_, false, minMonthlyFee_);

        _mint(to_, nodeId_);

        emit NodeAdded(nodeId_, to_, signingKeyPub_, httpAddress_, minMonthlyFee_);
    }

    /// @inheritdoc INodeRegistry
    function addToNetwork(uint256 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_);

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        require(!$.nodes[nodeId_].isCanonical, NodeAlreadyInCanonicalNetwork());
        require(++$.canonicalNodesCount <= $.maxCanonicalNodes, MaxCanonicalNodesReached());

        $.nodes[nodeId_].isCanonical = true;

        emit NodeAddedToCanonicalNetwork(nodeId_);
    }

    /// @inheritdoc INodeRegistry
    function removeFromNetwork(uint256 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_);

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
    function setNodeOperatorCommissionPercent(uint16 newCommissionPercent_) external onlyAdmin {
        require(newCommissionPercent_ <= MAX_BPS, InvalidCommissionPercent());
        _getNodeRegistryStorage().nodeOperatorCommissionPercent = newCommissionPercent_;
        emit NodeOperatorCommissionPercentUpdated(newCommissionPercent_);
    }

    /// @inheritdoc INodeRegistry
    function setBaseURI(string calldata newBaseURI_) external onlyAdmin {
        require(bytes(newBaseURI_).length > 0, InvalidURI());
        require(bytes(newBaseURI_)[bytes(newBaseURI_).length - 1] == _FORWARD_SLASH, InvalidURI());
        emit BaseURIUpdated(_getNodeRegistryStorage().baseURI = newBaseURI_);
    }

    /* ============ Node Manager Functions ============ */

    /// @inheritdoc INodeRegistry
    function setHttpAddress(uint256 nodeId_, string calldata httpAddress_) external onlyNodeManager {
        _requireOwned(nodeId_);
        require(bytes(httpAddress_).length > 0, InvalidHttpAddress());
        emit HttpAddressUpdated(nodeId_, _getNodeRegistryStorage().nodes[nodeId_].httpAddress = httpAddress_);
    }

    /// @inheritdoc INodeRegistry
    function setMinMonthlyFee(uint256 nodeId_, uint256 minMonthlyFee_) external onlyNodeManager {
        _requireOwned(nodeId_);
        emit MinMonthlyFeeUpdated(nodeId_, _getNodeRegistryStorage().nodes[nodeId_].minMonthlyFee = minMonthlyFee_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc INodeRegistry
    function updateAdmin() external {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        address newAdmin_ = _toAddress(_getRegistryParameter(adminParameterKey()));

        require(newAdmin_ != $.admin, NoChange());

        emit AdminUpdated($.admin = newAdmin_);
    }

    /// @inheritdoc INodeRegistry
    function updateNodeManager() external {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        address newNodeManager_ = _toAddress(_getRegistryParameter(nodeManagerParameterKey()));

        require(newNodeManager_ != $.nodeManager, NoChange());

        emit NodeManagerUpdated($.nodeManager = newNodeManager_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ Getters ============ */

    /// @inheritdoc INodeRegistry
    function admin() external view returns (address admin_) {
        return _getNodeRegistryStorage().admin;
    }

    /// @inheritdoc INodeRegistry
    function nodeManager() external view returns (address nodeManager_) {
        return _getNodeRegistryStorage().nodeManager;
    }

    /// @inheritdoc INodeRegistry
    function adminParameterKey() public pure returns (bytes memory key_) {
        return bytes("xmtp.nodeRegistry.admin");
    }

    /// @inheritdoc INodeRegistry
    function nodeManagerParameterKey() public pure returns (bytes memory key_) {
        return bytes("xmtp.nodeRegistry.nodeManager");
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
    function nodeOperatorCommissionPercent() external view returns (uint16 nodeOperatorCommissionPercent_) {
        return _getNodeRegistryStorage().nodeOperatorCommissionPercent;
    }

    /// @inheritdoc INodeRegistry
    function getAllNodes() external view returns (NodeWithId[] memory allNodes_) {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        allNodes_ = new NodeWithId[]($.nodeCount);

        for (uint32 index_; index_ < $.nodeCount; ++index_) {
            uint256 nodeId_ = uint256(NODE_INCREMENT) * (index_ + 1);
            allNodes_[index_] = NodeWithId({ nodeId: nodeId_, node: $.nodes[nodeId_] });
        }
    }

    /// @inheritdoc INodeRegistry
    function getAllNodesCount() external view returns (uint256 nodeCount_) {
        return _getNodeRegistryStorage().nodeCount;
    }

    /// @inheritdoc INodeRegistry
    function getNode(uint256 nodeId_) external view returns (Node memory node_) {
        _requireOwned(nodeId_);
        return _getNodeRegistryStorage().nodes[nodeId_];
    }

    /// @inheritdoc INodeRegistry
    function getIsCanonicalNode(uint256 nodeId_) external view returns (bool isCanonicalNode_) {
        _requireOwned(nodeId_);
        return _getNodeRegistryStorage().nodes[nodeId_].isCanonical;
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

    function _isAuthorized(
        address owner_,
        address spender_,
        uint256 tokenId_
    ) internal view override returns (bool isAuthorized_) {
        return spender_ == _getNodeRegistryStorage().nodeManager || super._isAuthorized(owner_, spender_, tokenId_);
    }

    function _revertIfNotAdmin() internal view {
        require(msg.sender == _getNodeRegistryStorage().admin, NotAdmin());
    }

    function _revertIfNotNodeManager() internal view {
        require(msg.sender == _getNodeRegistryStorage().nodeManager, NotNodeManager());
    }
}
