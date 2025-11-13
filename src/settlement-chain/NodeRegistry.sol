// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC721Upgradeable } from "../../lib/oz-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Node Registry
 *
 * @notice This contract is responsible for minting NFTs and assigning them to node owners.
 *         Each node is minted as an NFT with a unique ID (starting at 100 and increasing by 100 with each new node).
 *         In addition to the standard ERC721 functionality, the contract supports node-specific features,
 *         including node property updates.
 *
 * @dev    All nodes on the network periodically check this contract to determine which nodes they should connect to.
 */
contract NodeRegistry is INodeRegistry, Migratable, ERC721Upgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

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
     * @param  admin               The admin address.
     * @param  maxCanonicalNodes   The maximum number of canonical nodes.
     * @param  canonicalNodesCount The current number of canonical nodes.
     * @param  nodeCount           The current number of nodes.
     * @param  nodes               A mapping of node/token IDs to nodes.
     * @param  baseURI             The base component of the token URI.
     */
    struct NodeRegistryStorage {
        address admin;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
        mapping(uint32 tokenId => Node node) nodes;
        string baseURI;
        EnumerableSet.UintSet canonicalNodes;
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
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc INodeRegistry
    function initialize() public initializer {
        __ERC721_init("XMTP Nodes", "nXMTP");
    }

    /* ============ Admin Functions ============ */

    /// @inheritdoc INodeRegistry
    function addNode(
        address owner_,
        bytes calldata signingPublicKey_,
        string calldata httpAddress_
    ) external onlyAdmin returns (uint32 nodeId_, address signer_) {
        if (_isZero(owner_)) revert InvalidOwner();
        if (bytes(httpAddress_).length == 0) revert InvalidHttpAddress();

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if ((uint256($.nodeCount) + 1) * NODE_INCREMENT > type(uint32).max) revert MaxNodesReached();

        unchecked {
            nodeId_ = ++$.nodeCount * NODE_INCREMENT; // The first node starts with `nodeId_ = NODE_INCREMENT`.
        }

        signer_ = _getSignerFromPublicKey(signingPublicKey_);

        // Nodes start off as non-canonical.
        $.nodes[nodeId_] = Node(signer_, false, signingPublicKey_, httpAddress_);

        _mint(owner_, nodeId_);

        emit NodeAdded(nodeId_, owner_, signer_, signingPublicKey_, httpAddress_);
    }

    /// @inheritdoc INodeRegistry
    function addToNetwork(uint32 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if ($.nodes[nodeId_].isCanonical) return;

        if (++$.canonicalNodesCount > $.maxCanonicalNodes) revert MaxCanonicalNodesReached();

        $.nodes[nodeId_].isCanonical = true;

        if (!$.canonicalNodes.contains(nodeId_)) {
            require($.canonicalNodes.add(nodeId_));
        }

        emit NodeAddedToCanonicalNetwork(nodeId_);
    }

    /// @inheritdoc INodeRegistry
    function removeFromNetwork(uint32 nodeId_) external onlyAdmin {
        _requireOwned(nodeId_); // Reverts if the nodeId/tokenId does not exist.

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if (!$.nodes[nodeId_].isCanonical) return;

        delete $.nodes[nodeId_].isCanonical;

        if ($.canonicalNodes.contains(nodeId_)) {
            require($.canonicalNodes.remove(nodeId_));
        }

        --$.canonicalNodesCount;

        emit NodeRemovedFromCanonicalNetwork(nodeId_);
    }

    /// @inheritdoc INodeRegistry
    function setBaseURI(string calldata baseURI_) external onlyAdmin {
        if (bytes(baseURI_).length == 0) revert InvalidURI();
        if (bytes(baseURI_)[bytes(baseURI_).length - 1] != _FORWARD_SLASH) revert InvalidURI();
        emit BaseURIUpdated(_getNodeRegistryStorage().baseURI = baseURI_);
    }

    /* ============ Node Owner Functions ============ */

    /// @inheritdoc INodeRegistry
    function setHttpAddress(uint32 nodeId_, string calldata httpAddress_) external {
        _revertIfNotNodeOwner(nodeId_);

        if (bytes(httpAddress_).length == 0) revert InvalidHttpAddress();

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if (keccak256(bytes($.nodes[nodeId_].httpAddress)) == keccak256(bytes(httpAddress_))) revert NoChange();

        $.nodes[nodeId_].httpAddress = httpAddress_;

        emit HttpAddressUpdated(nodeId_, httpAddress_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc INodeRegistry
    function updateAdmin() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        address admin_ = RegistryParameters.getAddressParameter(parameterRegistry, adminParameterKey());

        if (_isZero(admin_)) revert ZeroAdmin();

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if (admin_ == $.admin) revert NoChange();

        emit AdminUpdated($.admin = admin_);
    }

    /// @inheritdoc INodeRegistry
    function updateMaxCanonicalNodes() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        uint8 maxCanonicalNodes_ = RegistryParameters.getUint8Parameter(
            parameterRegistry,
            maxCanonicalNodesParameterKey()
        );

        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        if (maxCanonicalNodes_ == $.maxCanonicalNodes) revert NoChange();
        if (maxCanonicalNodes_ < $.canonicalNodesCount) revert MaxCanonicalNodesBelowCurrentCount();

        emit MaxCanonicalNodesUpdated($.maxCanonicalNodes = maxCanonicalNodes_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc INodeRegistry
    function admin() external view returns (address admin_) {
        return _getNodeRegistryStorage().admin;
    }

    /// @inheritdoc INodeRegistry
    function adminParameterKey() public pure returns (string memory key_) {
        return "xmtp.nodeRegistry.admin";
    }

    /// @inheritdoc INodeRegistry
    function maxCanonicalNodesParameterKey() public pure returns (string memory key_) {
        return "xmtp.nodeRegistry.maxCanonicalNodes";
    }

    /// @inheritdoc INodeRegistry
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.nodeRegistry.migrator";
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
    function getCanonicalNodes() external view returns (uint32[] memory canonicalNodes_) {
        NodeRegistryStorage storage $ = _getNodeRegistryStorage();

        canonicalNodes_ = new uint32[]($.canonicalNodes.length());

        for (uint256 i = 0; i < $.canonicalNodes.length(); i++) {
            // Casting to uint32 is safe because the set only contains uint32 values.
            // forge-lint: disable-next-line(unsafe-typecast)
            canonicalNodes_[i] = uint32($.canonicalNodes.at(i));
        }

        return canonicalNodes_;
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

    /**
     * @notice Returns the signer address from a public key.
     * @param  publicKey_ The public key.
     * @return signer_    The signer address.
     * @dev    Validates uncompressed public key format: 0x04 + 32 bytes X + 32 bytes Y = 65 bytes total
     */
    function _getSignerFromPublicKey(bytes calldata publicKey_) internal pure returns (address signer_) {
        if (publicKey_.length != 65 || bytes1(publicKey_[:1]) != 0x04) revert InvalidSigningPublicKey();

        return address(uint160(uint256(keccak256(publicKey_[1:65]))));
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfNotAdmin() internal view {
        if (msg.sender != _getNodeRegistryStorage().admin) revert NotAdmin();
    }

    function _revertIfNotNodeOwner(uint32 nodeId_) internal view {
        if (_requireOwned(nodeId_) != msg.sender) revert NotNodeOwner();
    }
}
