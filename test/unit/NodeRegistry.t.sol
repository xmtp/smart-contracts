// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC721 } from "../../lib/oz/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { NodeRegistryHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract NodeRegistryTests is Test {
    bytes internal constant _ADMIN_KEY = "xmtp.nodeRegistry.admin";
    bytes internal constant _MIGRATOR_KEY = "xmtp.nodeRegistry.migrator";

    uint32 internal constant _NODE_INCREMENT = 100;

    NodeRegistryHarness internal _registry;

    address internal _implementation;
    address internal _parameterRegistry;

    address internal _admin = makeAddr("admin");
    address internal _unauthorized = makeAddr("unauthorized");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new NodeRegistryHarness(_parameterRegistry));

        _registry = NodeRegistryHarness(address(new Proxy(_implementation)));

        _registry.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(INodeRegistry.ZeroParameterRegistry.selector);
        new NodeRegistryHarness(address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(keccak256(_registry.adminParameterKey()), keccak256(_ADMIN_KEY));
        assertEq(keccak256(_registry.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(_registry.name(), "XMTP Nodes");
        assertEq(_registry.symbol(), "nXMTP");
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.maxCanonicalNodes(), 20);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _registry.initialize();
    }

    /* ============ addNode ============ */

    function test_addNode_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.addNode(address(0), hex"", "");
    }

    function test_addNode_invalidOwner() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidOwner.selector);

        vm.prank(_admin);
        _registry.addNode(address(0), hex"", "");
    }

    function test_addNode_invalidSigningPublicKey() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidSigningPublicKey.selector);

        vm.prank(_admin);
        _registry.addNode(address(1), hex"", "");
    }

    function test_addNode_invalidHttpAddress() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidHttpAddress.selector);

        vm.prank(_admin);
        _registry.addNode(address(1), hex"1f", "");
    }

    function test_addNode_maxNodesReached() external {
        _registry.__setAdmin(_admin);
        _registry.__setNodeCount((type(uint32).max / _NODE_INCREMENT) + 1);

        vm.expectRevert(INodeRegistry.MaxNodesReached.selector);

        vm.prank(_admin);
        _registry.addNode(address(1), hex"1f", "http://example.com");
    }

    function test_addNode_first() external {
        _registry.__setAdmin(_admin);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeAdded(
            _NODE_INCREMENT,
            address(1),
            0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC,
            hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f",
            "http://example.com"
        );

        vm.prank(_admin);
        (uint32 nodeId_, address signer_) = _registry.addNode(
            address(1),
            hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f",
            "http://example.com"
        );

        assertEq(nodeId_, _NODE_INCREMENT);
        assertEq(signer_, 0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC);

        assertEq(_registry.__getOwner(nodeId_), address(1));

        assertEq(_registry.__getNode(nodeId_).signer, 0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC);
        assertEq(_registry.__getNode(nodeId_).isCanonical, false);
        assertEq(_registry.__getNode(nodeId_).signingPublicKey, hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f");
        assertEq(_registry.__getNode(nodeId_).httpAddress, "http://example.com");

        assertEq(_registry.__getNodeCount(), 1);
        assertEq(_registry.canonicalNodesCount(), 0);
    }

    function test_addNode_nth() external {
        _registry.__setAdmin(_admin);
        _registry.__setNodeCount(11);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeAdded(
            _NODE_INCREMENT * 12,
            address(1),
            0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC,
            hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f",
            "http://example.com"
        );

        vm.prank(_admin);
        (uint32 nodeId_, address signer_) = _registry.addNode(
            address(1),
            hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f",
            "http://example.com"
        );

        assertEq(nodeId_, _NODE_INCREMENT * 12);
        assertEq(signer_, 0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC);

        assertEq(_registry.__getOwner(nodeId_), address(1));

        assertEq(_registry.__getNode(nodeId_).signer, 0xaae97Cb335d7F39A7D89717918Ad6F52f50739FC);
        assertEq(_registry.__getNode(nodeId_).isCanonical, false);
        assertEq(_registry.__getNode(nodeId_).signingPublicKey, hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f");
        assertEq(_registry.__getNode(nodeId_).httpAddress, "http://example.com");

        assertEq(_registry.__getNodeCount(), 12);
        assertEq(_registry.canonicalNodesCount(), 0);
    }

    /* ============ addToNetwork ============ */

    function test_addToNetwork_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.addToNetwork(0);
    }

    function test_addToNetwork_nonexistentToken() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        vm.prank(_admin);
        _registry.addToNetwork(1);
    }

    function test_addToNetwork_alreadyInCanonicalNetwork() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, address(0), true, "", "");

        vm.expectRevert(INodeRegistry.NodeAlreadyInCanonicalNetwork.selector);

        vm.prank(_admin);
        _registry.addToNetwork(1);
    }

    function test_addToNetwork_maxActiveNodesReached() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, address(0), false, "", "");

        _registry.__setMaxCanonicalNodes(0);

        vm.expectRevert(INodeRegistry.MaxCanonicalNodesReached.selector);

        vm.prank(_admin);
        _registry.addToNetwork(1);

        _registry.__setMaxCanonicalNodes(10);
        _registry.__setCanonicalNodesCount(10);

        vm.expectRevert(INodeRegistry.MaxCanonicalNodesReached.selector);

        vm.prank(_admin);
        _registry.addToNetwork(1);
    }

    function test_addToNetwork() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, address(0), false, "", "");

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeAddedToCanonicalNetwork(1);

        vm.prank(_admin);
        _registry.addToNetwork(1);

        assertTrue(_registry.__getNode(1).isCanonical);
        assertEq(_registry.canonicalNodesCount(), 1);
    }

    /* ============ removeFromNetwork ============ */

    function test_removeFromNetwork_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.removeFromNetwork(0);
    }

    function test_removeFromNetwork_notInCanonicalNetwork() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, address(0), false, "", "");

        vm.expectRevert(INodeRegistry.NodeNotInCanonicalNetwork.selector);

        vm.prank(_admin);
        _registry.removeFromNetwork(1);
    }

    function test_removeFromNetwork_nonexistentToken() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        vm.prank(_admin);
        _registry.removeFromNetwork(1);
    }

    function test_removeFromNetwork() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, address(0), true, "", "");

        _registry.__addNodeToCanonicalNetwork(1);
        _registry.__setCanonicalNodesCount(1);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeRemovedFromCanonicalNetwork(1);

        vm.prank(_admin);
        _registry.removeFromNetwork(1);

        assertFalse(_registry.__getNode(1).isCanonical);
        assertEq(_registry.canonicalNodesCount(), 0);
    }

    /* ============ setHttpAddress ============ */

    function test_setHttpAddress_notNodeOwner() external {
        _addNode(1, _alice, address(0), false, "", "");

        vm.expectRevert(INodeRegistry.NotNodeOwner.selector);

        vm.prank(_unauthorized);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_nonexistentToken() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        vm.prank(_alice);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_invalidHttpAddress() external {
        _addNode(1, _alice, address(0), false, "", "");

        vm.expectRevert(INodeRegistry.InvalidHttpAddress.selector);

        vm.prank(_alice);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress() external {
        _addNode(1, _alice, address(0), false, "", "");

        vm.expectEmit(address(_registry));

        emit INodeRegistry.HttpAddressUpdated(1, "http://example.com");

        vm.prank(_alice);
        _registry.setHttpAddress(1, "http://example.com");

        assertEq(_registry.__getNode(1).httpAddress, "http://example.com");
    }

    /* ============ setMaxCanonicalNodes ============ */

    function test_setMaxActiveNodes_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setMaxCanonicalNodes(0);
    }

    function test_setMaxCanonicalNodes_lessThanActiveNodesLength() external {
        _registry.__setAdmin(_admin);
        _registry.__setCanonicalNodesCount(1);

        vm.expectRevert(INodeRegistry.MaxCanonicalNodesBelowCurrentCount.selector);

        vm.prank(_admin);
        _registry.setMaxCanonicalNodes(0);
    }

    function test_setMaxCanonicalNodes() external {
        _registry.__setAdmin(_admin);
        vm.expectEmit(address(_registry));
        emit INodeRegistry.MaxCanonicalNodesUpdated(10);

        vm.prank(_admin);
        _registry.setMaxCanonicalNodes(10);

        assertEq(_registry.maxCanonicalNodes(), 10);
    }

    /* ============ setBaseURI ============ */

    function test_setBaseURI_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setBaseURI("");
    }

    function test_setBaseURI_invalidURI_empty() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidURI.selector);

        vm.prank(_admin);
        _registry.setBaseURI("");
    }

    function test_setBaseURI_invalidURI_missingTrailingSlash() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidURI.selector);

        vm.prank(_admin);
        _registry.setBaseURI("http://example.com");
    }

    function test_setBaseURI() external {
        _registry.__setAdmin(_admin);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.BaseURIUpdated("http://example.com/");

        vm.prank(_admin);
        _registry.setBaseURI("http://example.com/");

        assertEq(_registry.__getBaseURI(), "http://example.com/");
    }

    /* ============ updateAdmin ============ */

    function test_updateAdmin_noChange() external {
        _registry.__setAdmin(_admin);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _ADMIN_KEY, bytes32(uint256(uint160(_admin))));

        vm.expectRevert(INodeRegistry.NoChange.selector);

        _registry.updateAdmin();
    }

    function test_updateAdmin() external {
        _registry.__setAdmin(_admin);

        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _ADMIN_KEY, bytes32(uint256(1)));

        vm.expectEmit(address(_registry));
        emit INodeRegistry.AdminUpdated(address(1));

        _registry.updateAdmin();
    }

    /* ============ maxCanonicalNodes ============ */

    function test_maxCanonicalNodes() external {
        _registry.__setMaxCanonicalNodes(10);

        assertEq(_registry.maxCanonicalNodes(), 10);

        _registry.__setMaxCanonicalNodes(20);

        assertEq(_registry.maxCanonicalNodes(), 20);
    }

    /* ============ canonicalNodesCount ============ */

    function test_canonicalNodesCount() external {
        _registry.__setCanonicalNodesCount(10);

        assertEq(_registry.canonicalNodesCount(), 10);

        _registry.__setCanonicalNodesCount(20);

        assertEq(_registry.canonicalNodesCount(), 20);
    }

    /* ============ getAllNodes ============ */

    function test_getAllNodes() external {
        INodeRegistry.NodeWithId[] memory allNodes_;

        _addNode(_NODE_INCREMENT, _alice, address(0), false, "", "");
        _registry.__setNodeCount(1);

        allNodes_ = _registry.getAllNodes();

        assertEq(allNodes_.length, 1);
        assertEq(allNodes_[0].nodeId, _NODE_INCREMENT);

        _addNode(_NODE_INCREMENT * 2, _alice, address(0), false, "", "");
        _registry.__setNodeCount(2);

        allNodes_ = _registry.getAllNodes();

        assertEq(allNodes_.length, 2);
        assertEq(allNodes_[0].nodeId, _NODE_INCREMENT);
        assertEq(allNodes_[1].nodeId, _NODE_INCREMENT * 2);
    }

    /* ============ getAllNodesCount ============ */

    function test_getAllNodesCount() external {
        _registry.__setNodeCount(1);

        assertEq(_registry.getAllNodesCount(), 1);

        _registry.__setNodeCount(2);

        assertEq(_registry.getAllNodesCount(), 2);
    }

    /* ============ getNode ============ */

    function test_getNode_nonexistentToken() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        _registry.getNode(1);
    }

    function test_getNode() external {
        _addNode(1, _alice, address(2), true, hex"1f1f1f", "httpAddress");

        INodeRegistry.Node memory node_ = _registry.getNode(1);

        assertEq(node_.signer, address(2));
        assertTrue(node_.isCanonical);
        assertEq(node_.signingPublicKey, hex"1f1f1f");
        assertEq(node_.httpAddress, "httpAddress");
    }

    /* ============ getIsCanonicalNode ============ */

    function test_getIsCanonicalNode_nonexistentToken() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        _registry.getIsCanonicalNode(1);
    }

    function test_getIsCanonicalNode() external {
        _addNode(1, _alice, address(0), true, hex"", "");

        assertTrue(_registry.getIsCanonicalNode(1));

        _registry.__removeNodeFromCanonicalNetwork(1);

        assertFalse(_registry.getIsCanonicalNode(1));
    }

    /* ============ getSigner ============ */

    function test_getSigner_nonexistentToken() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        _registry.getSigner(1);
    }

    function test_getSigner() external {
        _addNode(1, _alice, address(2), false, hex"", "");

        assertEq(_registry.getSigner(1), address(2));

        _registry.__removeNodeFromCanonicalNetwork(1);

        assertEq(_registry.getSigner(1), address(2));
    }

    /* ============ admin ============ */

    function test_admin() external {
        _registry.__setAdmin(_admin);

        assertEq(_registry.admin(), _admin);

        _registry.__setAdmin(address(1));

        assertEq(_registry.admin(), address(1));
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _registry.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                migrator_,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _registry.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _registry.migrate();
    }

    function test_migrate() external {
        _registry.__setNodeCount(100);

        address newImplementation_ = address(new NodeRegistryHarness(_parameterRegistry));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_registry));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation_);

        _registry.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_registry)), newImplementation_);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.__getNodeCount(), 100);
    }

    /* ============ helper functions ============ */

    function _addNode(
        uint256 nodeId_,
        address owner_,
        address signer_,
        bool inCanonical_,
        bytes memory signingPublicKey_,
        string memory httpAddress_
    ) internal {
        _registry.__setNode(nodeId_, signer_, inCanonical_, signingPublicKey_, httpAddress_);
        _registry.__mint(owner_, nodeId_);
    }
}
