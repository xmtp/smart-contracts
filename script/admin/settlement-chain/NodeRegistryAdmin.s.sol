// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { INodeRegistry } from "../../../src/settlement-chain/interfaces/INodeRegistry.sol";
import { Utils } from "../../utils/Utils.sol";
import { AdminAddressTypeLib } from "../../utils/AdminAddressType.sol";

/**
 * @title  Node Registry Admin Operations
 * @notice Calls admin functions on the NodeRegistry contract.
 *         The caller must be the NodeRegistry admin (set via the parameter registry).
 * @dev    Admin address type is determined by environment with optional ADMIN_ADDRESS_TYPE override.
 *         See AdminAddressTypeLib for environment-specific defaults.
 * @dev    Environment variables:
 *         - NODE_REGISTRY_ADMIN_PRIVATE_KEY: Required when using WALLET mode
 *         - NODE_REGISTRY_ADMIN_ADDRESS: Required when using FIREBLOCKS mode
 */
contract NodeRegistryAdmin is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error AdminNotSet();
    error UnexpectedChainId();

    string internal _environment;
    uint256 internal _adminPrivateKey;
    address internal _admin;
    AdminAddressTypeLib.AdminAddressType internal _adminAddressType;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        _adminAddressType = AdminAddressTypeLib.getAdminAddressType(_environment);

        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            _adminPrivateKey = uint256(vm.envBytes32("NODE_REGISTRY_ADMIN_PRIVATE_KEY"));
            if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
            _admin = vm.addr(_adminPrivateKey);
            console.log("NodeRegistry Admin (Wallet): %s", _admin);
        } else {
            _admin = vm.envAddress("NODE_REGISTRY_ADMIN_ADDRESS");
            if (_admin == address(0)) revert AdminNotSet();
            console.log("NodeRegistry Admin (Fireblocks): %s", _admin);
        }
    }

    /* ============ Admin Functions ============ */

    /**
     * @notice Adds a new node to the registry
     * @param owner_ The address that will own the node NFT
     * @param signingPublicKey_ The 65-byte uncompressed public key (0x04 + X + Y)
     * @param httpAddress_ The node's HTTP endpoint
     */
    function addNode(address owner_, bytes calldata signingPublicKey_, string calldata httpAddress_) external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);
        console.log("Owner: %s", owner_);
        console.log("HTTP Address: %s", httpAddress_);

        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        (uint32 nodeId, address signer) = INodeRegistry(nodeRegistry).addNode(owner_, signingPublicKey_, httpAddress_);
        console.log("Node added successfully");
        console.log("Node ID: %s", uint256(nodeId));
        console.log("Signer: %s", signer);

        vm.stopBroadcast();
    }

    /**
     * @notice Adds a node to the canonical network
     * @param nodeId_ The node ID to add to the network
     */
    function addToNetwork(uint32 nodeId_) external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);
        console.log("Node ID: %s", uint256(nodeId_));

        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        INodeRegistry(nodeRegistry).addToNetwork(nodeId_);
        console.log("Node added to canonical network");

        vm.stopBroadcast();
    }

    /**
     * @notice Removes a node from the canonical network
     * @param nodeId_ The node ID to remove from the network
     */
    function removeFromNetwork(uint32 nodeId_) external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);
        console.log("Node ID: %s", uint256(nodeId_));

        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        INodeRegistry(nodeRegistry).removeFromNetwork(nodeId_);
        console.log("Node removed from canonical network");

        vm.stopBroadcast();
    }

    /**
     * @notice Sets the base URI for node NFTs
     * @param baseURI_ The new base URI (must end with a trailing slash)
     */
    function setBaseURI(string calldata baseURI_) external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);
        console.log("Base URI: %s", baseURI_);

        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        INodeRegistry(nodeRegistry).setBaseURI(baseURI_);
        console.log("Base URI set successfully");

        vm.stopBroadcast();
    }

    /* ============ View Functions ============ */

    /**
     * @notice Gets all nodes in the registry
     */
    function getAllNodes() external view {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);

        INodeRegistry.NodeWithId[] memory nodes = INodeRegistry(nodeRegistry).getAllNodes();
        console.log("Total nodes: %s", nodes.length);

        for (uint256 i; i < nodes.length; ++i) {
            console.log("---");
            console.log("Node ID: %s", uint256(nodes[i].nodeId));
            console.log("  Signer: %s", nodes[i].node.signer);
            console.log("  Is Canonical: %s", nodes[i].node.isCanonical);
            console.log("  HTTP Address: %s", nodes[i].node.httpAddress);
        }
    }

    /**
     * @notice Gets all canonical node IDs
     */
    function getCanonicalNodes() external view {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);

        uint32[] memory canonicalNodes = INodeRegistry(nodeRegistry).getCanonicalNodes();
        console.log("Canonical nodes count: %s", canonicalNodes.length);
        console.log("Max canonical nodes: %s", uint256(INodeRegistry(nodeRegistry).maxCanonicalNodes()));

        for (uint256 i; i < canonicalNodes.length; ++i) {
            console.log("  Canonical Node ID: %s", uint256(canonicalNodes[i]));
        }
    }

    /**
     * @notice Gets details for a specific node
     * @param nodeId_ The node ID to query
     */
    function getNode(uint32 nodeId_) external view {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);

        INodeRegistry.Node memory node = INodeRegistry(nodeRegistry).getNode(nodeId_);
        console.log("Node ID: %s", uint256(nodeId_));
        console.log("  Owner: %s", INodeRegistry(nodeRegistry).ownerOf(nodeId_));
        console.log("  Signer: %s", node.signer);
        console.log("  Is Canonical: %s", node.isCanonical);
        console.log("  HTTP Address: %s", node.httpAddress);
    }

    /**
     * @notice Gets the current admin address
     */
    function getAdmin() external view {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address nodeRegistry = _deployment.nodeRegistryProxy;

        console.log("NodeRegistry: %s", nodeRegistry);
        console.log("Admin: %s", INodeRegistry(nodeRegistry).admin());
    }
}
