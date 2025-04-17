// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC721 } from "../../lib/oz/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";

import { NodeRegistryHarness } from "../utils/Harnesses.sol";
import { MockParameterRegistry, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract NodeRegistryTests is Test, Utils {
    bytes internal constant _ADMIN_KEY = "xmtp.nodeRegistry.admin";
    bytes internal constant _NODE_MANAGER_KEY = "xmtp.nodeRegistry.nodeManager";
    bytes internal constant _MIGRATOR_KEY = "xmtp.nodeRegistry.migrator";

    uint32 internal constant _NODE_INCREMENT = 100;

    uint16 internal constant _MAX_BPS = 10_000;

    NodeRegistryHarness internal _registry;

    address internal _implementation;
    address internal _parameterRegistry;

    address internal _admin = makeAddr("admin");
    address internal _manager = makeAddr("manager");
    address internal _unauthorized = makeAddr("unauthorized");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _implementation = address(new NodeRegistryHarness(_parameterRegistry));

        _registry = NodeRegistryHarness(
            address(new ERC1967Proxy(_implementation, abi.encodeWithSelector(INodeRegistry.initialize.selector)))
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistryAddress() external {
        vm.expectRevert(INodeRegistry.ZeroParameterRegistryAddress.selector);

        new NodeRegistryHarness(address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_registry)), _implementation);
        assertEq(_registry.implementation(), _implementation);
        assertEq(keccak256(_registry.adminParameterKey()), keccak256(_ADMIN_KEY));
        assertEq(keccak256(_registry.nodeManagerParameterKey()), keccak256(_NODE_MANAGER_KEY));
        assertEq(keccak256(_registry.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
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
        _registry.addNode(address(0), hex"", "", 0);
    }

    function test_addNode_invalidAddress() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidAddress.selector);

        vm.prank(_admin);
        _registry.addNode(address(0), hex"", "", 0);
    }

    function test_addNode_invalidSigningKey() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidSigningKey.selector);

        vm.prank(_admin);
        _registry.addNode(address(1), hex"", "", 1000);
    }

    function test_addNode_invalidHttpAddress() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidHttpAddress.selector);

        vm.prank(_admin);
        _registry.addNode(address(1), hex"1F", "", 1000);
    }

    function test_addNode_first() external {
        _registry.__setAdmin(_admin);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeAdded(
            _NODE_INCREMENT,
            address(1),
            hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            "http://example.com",
            1000
        );

        vm.prank(_admin);
        uint256 nodeId_ = _registry.addNode(
            address(1),
            hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            "http://example.com",
            1000
        );

        assertEq(nodeId_, _NODE_INCREMENT);

        assertEq(_registry.__getOwner(nodeId_), address(1));

        assertEq(_registry.__getNode(nodeId_).signingKeyPub, hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");
        assertEq(_registry.__getNode(nodeId_).httpAddress, "http://example.com");
        assertEq(_registry.__getNode(nodeId_).isCanonical, false);
        assertEq(_registry.__getNode(nodeId_).minMonthlyFee, 1000);

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
            hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            "http://example.com",
            1000
        );

        vm.prank(_admin);
        uint256 nodeId_ = _registry.addNode(
            address(1),
            hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            "http://example.com",
            1000
        );

        assertEq(nodeId_, _NODE_INCREMENT * 12);

        assertEq(_registry.__getOwner(nodeId_), address(1));

        assertEq(_registry.__getNode(nodeId_).signingKeyPub, hex"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");
        assertEq(_registry.__getNode(nodeId_).httpAddress, "http://example.com");
        assertEq(_registry.__getNode(nodeId_).isCanonical, false);
        assertEq(_registry.__getNode(nodeId_).minMonthlyFee, 1000);

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
        _addNode(1, _alice, "", "", true, 0);

        vm.expectRevert(INodeRegistry.NodeAlreadyInCanonicalNetwork.selector);

        vm.prank(_admin);
        _registry.addToNetwork(1);
    }

    function test_addToNetwork_maxActiveNodesReached() external {
        _registry.__setAdmin(_admin);
        _addNode(1, _alice, "", "", false, 0);

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
        _addNode(1, _alice, "", "", false, 0);

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
        _addNode(1, _alice, "", "", false, 0);

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
        _addNode(1, _alice, "", "", true, 0);

        _registry.__addNodeToCanonicalNetwork(1);
        _registry.__setCanonicalNodesCount(1);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeRemovedFromCanonicalNetwork(1);

        vm.prank(_admin);
        _registry.removeFromNetwork(1);

        assertFalse(_registry.__getNode(1).isCanonical);
        assertEq(_registry.canonicalNodesCount(), 0);
    }

    /* ============ transferFrom ============ */

    function test_transferFrom_unauthorized() external {
        _addNode(1, _alice, "", "", false, 0);

        vm.expectRevert();

        vm.prank(_unauthorized);
        _registry.transferFrom(_alice, _bob, 1);
    }

    function test_transferFrom_asOperator() external {
        _addNode(1, _alice, "", "", false, 0);

        vm.expectEmit(address(_registry));
        emit IERC721.Transfer(_alice, _bob, 1);

        vm.prank(_alice);
        _registry.transferFrom(_alice, _bob, 1);

        assertEq(_registry.ownerOf(1), _bob);
    }

    function test_transferFrom_asNodeManager() external {
        _registry.__setNodeManager(_manager);
        _addNode(1, _alice, "", "", false, 0);

        vm.expectEmit(address(_registry));
        emit IERC721.Transfer(_alice, _bob, 1);

        vm.prank(_manager);
        _registry.transferFrom(_alice, _bob, 1);

        assertEq(_registry.ownerOf(1), _bob);
    }

    /* ============ setHttpAddress ============ */

    function test_setHttpAddress_notManager() external {
        _registry.__setNodeManager(_manager);

        _addNode(1, _alice, "", "", false, 0);

        vm.expectRevert(INodeRegistry.NotNodeManager.selector);

        vm.prank(_unauthorized);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_nonexistentToken() external {
        _registry.__setNodeManager(_manager);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        vm.prank(_manager);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_invalidHttpAddress() external {
        _registry.__setNodeManager(_manager);

        _addNode(1, _alice, "", "", false, 0);

        vm.expectRevert(INodeRegistry.InvalidHttpAddress.selector);

        vm.prank(_manager);
        _registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress() external {
        _registry.__setNodeManager(_manager);

        _addNode(1, _alice, "", "", false, 0);

        vm.expectEmit(address(_registry));

        emit INodeRegistry.HttpAddressUpdated(1, "http://example.com");

        vm.prank(_manager);
        _registry.setHttpAddress(1, "http://example.com");

        assertEq(_registry.__getNode(1).httpAddress, "http://example.com");
    }

    /* ============ setMinMonthlyFee ============ */

    function test_setMinMonthlyFee_notManager() external {
        _registry.__setNodeManager(_manager);

        vm.expectRevert(INodeRegistry.NotNodeManager.selector);

        vm.prank(_unauthorized);
        _registry.setMinMonthlyFee(1, 0);
    }

    function test_setMinMonthlyFee_nonexistentToken() external {
        _registry.__setNodeManager(_manager);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        vm.prank(_manager);
        _registry.setMinMonthlyFee(1, 0);
    }

    function test_setMinMonthlyFee() external {
        _registry.__setNodeManager(_manager);

        _addNode(1, _alice, "", "", false, 0);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.MinMonthlyFeeUpdated(1, 1000);

        vm.prank(_manager);
        _registry.setMinMonthlyFee(1, 1000);

        assertEq(_registry.__getNode(1).minMonthlyFee, 1000);
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

    /* ============ setNodeOperatorCommissionPercent ============ */

    function test_setNodeOperatorCommissionPercent_notAdmin() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.NotAdmin.selector);

        vm.prank(_unauthorized);
        _registry.setNodeOperatorCommissionPercent(0);
    }

    function test_setNodeOperatorCommissionPercent_invalidCommissionPercent() external {
        _registry.__setAdmin(_admin);

        vm.expectRevert(INodeRegistry.InvalidCommissionPercent.selector);

        vm.prank(_admin);
        _registry.setNodeOperatorCommissionPercent(_MAX_BPS + 1);
    }

    function test_setNodeOperatorCommissionPercent() external {
        _registry.__setAdmin(_admin);

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeOperatorCommissionPercentUpdated(1000);

        vm.prank(_admin);
        _registry.setNodeOperatorCommissionPercent(1000);

        assertEq(_registry.nodeOperatorCommissionPercent(), 1000);
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

        _mockParameterRegistryCall(_ADMIN_KEY, _admin);

        vm.expectRevert(INodeRegistry.NoChange.selector);

        _registry.updateAdmin();
    }

    function test_updateAdmin() external {
        _registry.__setAdmin(_admin);

        _mockParameterRegistryCall(_ADMIN_KEY, address(1));

        vm.expectEmit(address(_registry));
        emit INodeRegistry.AdminUpdated(address(1));

        _registry.updateAdmin();
    }

    /* ============ updateNodeManager ============ */

    function test_updateNodeManager_noChange() external {
        _registry.__setNodeManager(_manager);

        _mockParameterRegistryCall(_NODE_MANAGER_KEY, _manager);

        vm.expectRevert(INodeRegistry.NoChange.selector);

        _registry.updateNodeManager();
    }

    function test_updateNodeManager() external {
        _registry.__setNodeManager(_manager);

        _mockParameterRegistryCall(_NODE_MANAGER_KEY, address(1));

        vm.expectEmit(address(_registry));
        emit INodeRegistry.NodeManagerUpdated(address(1));

        _registry.updateNodeManager();
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

    /* ============ nodeOperatorCommissionPercent ============ */

    function test_nodeOperatorCommissionPercent() external {
        _registry.__setNodeOperatorCommissionPercent(1000);

        assertEq(_registry.nodeOperatorCommissionPercent(), 1000);

        _registry.__setNodeOperatorCommissionPercent(2000);

        assertEq(_registry.nodeOperatorCommissionPercent(), 2000);
    }

    /* ============ getAllNodes ============ */

    function test_getAllNodes() external {
        INodeRegistry.NodeWithId[] memory allNodes_;

        _addNode(_NODE_INCREMENT, _alice, "", "", false, 0);
        _registry.__setNodeCount(1);

        allNodes_ = _registry.getAllNodes();

        assertEq(allNodes_.length, 1);
        assertEq(allNodes_[0].nodeId, _NODE_INCREMENT);

        _addNode(_NODE_INCREMENT * 2, _alice, "", "", false, 0);
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
        _addNode(1, _alice, hex"1F1F1F", "httpAddress", true, 1000);

        INodeRegistry.Node memory node_ = _registry.getNode(1);

        assertEq(node_.signingKeyPub, hex"1F1F1F");
        assertEq(node_.httpAddress, "httpAddress");
        assertEq(node_.minMonthlyFee, 1000);
        assertTrue(node_.isCanonical);
    }

    /* ============ getIsCanonicalNode ============ */

    function test_getIsCanonicalNode_nonexistentToken() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));

        _registry.getIsCanonicalNode(1);
    }

    function test_getIsCanonicalNode() external {
        _addNode(1, _alice, hex"1F1F1F", "httpAddress", true, 1000);

        assertTrue(_registry.getIsCanonicalNode(1));

        _registry.__removeNodeFromCanonicalNetwork(1);

        assertFalse(_registry.getIsCanonicalNode(1));
    }

    /* ============ admin ============ */

    function test_admin() external {
        _registry.__setAdmin(_admin);

        assertEq(_registry.admin(), _admin);

        _registry.__setAdmin(address(1));

        assertEq(_registry.admin(), address(1));
    }

    /* ============ nodeManager ============ */

    function test_nodeManager() external {
        _registry.__setNodeManager(_manager);

        assertEq(_registry.nodeManager(), _manager);

        _registry.__setNodeManager(address(1));

        assertEq(_registry.nodeManager(), address(1));
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _registry.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _registry.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockParameterRegistryCall(_MIGRATOR_KEY, address(1));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _registry.migrate();
    }

    function test_migrate() external {
        _registry.__setNodeCount(100);
        _registry.__setNodeOperatorCommissionPercent(50);

        address newImplementation_ = address(new NodeRegistryHarness(_parameterRegistry));
        address migrator_ = address(new MockMigrator(newImplementation_));

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_registry));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_registry));
        emit IERC1967.Upgraded(newImplementation_);

        _registry.migrate();

        assertEq(_getImplementationFromSlot(address(_registry)), newImplementation_);
        assertEq(_registry.parameterRegistry(), _parameterRegistry);
        assertEq(_registry.__getNodeCount(), 100);
        assertEq(_registry.nodeOperatorCommissionPercent(), 50);
    }

    /* ============ helper functions ============ */

    function _addNode(
        uint256 nodeId_,
        address operator_,
        bytes memory signingKeyPub_,
        string memory httpAddress_,
        bool inCanonical_,
        uint256 minMonthlyFee_
    ) internal {
        _registry.__setNode(nodeId_, signingKeyPub_, httpAddress_, inCanonical_, minMonthlyFee_);
        _registry.__mint(operator_, nodeId_);
    }

    function _mockParameterRegistryCall(bytes memory key_, address value_) internal {
        _mockParameterRegistryCall(key_, bytes32(uint256(uint160(value_))));
    }

    function _mockParameterRegistryCall(bytes memory key_, bool value_) internal {
        _mockParameterRegistryCall(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function _mockParameterRegistryCall(bytes memory key_, uint256 value_) internal {
        _mockParameterRegistryCall(key_, bytes32(value_));
    }

    function _mockParameterRegistryCall(bytes memory key_, bytes32 value_) internal {
        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes)", key_), abi.encode(value_));
    }

    function _getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(vm.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
