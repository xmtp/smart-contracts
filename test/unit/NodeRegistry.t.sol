// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { console } from "../../lib/forge-std/src/console.sol";

import { IAccessControl } from "../../lib/oz/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "../../lib/oz/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { IERC721 } from "../../lib/oz/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "../../lib/oz/contracts/interfaces/draft-IERC6093.sol";
import { IERC165 } from "../../lib/oz/contracts/interfaces/IERC165.sol";
import { ERC721 } from "../../lib/oz/contracts/token/ERC721/ERC721.sol";

import { INodeRegistry, INodeRegistryEvents, INodeRegistryErrors } from "../../src/interfaces/INodeRegistry.sol";

import { NodeRegistryHarness } from "../utils/Harnesses.sol";
import { Utils } from "../utils/Utils.sol";

contract NodeRegistryTests is Test, Utils {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 constant NODE_MANAGER_ROLE = keccak256("NODE_MANAGER_ROLE");

    uint32 constant NODE_INCREMENT = 100;

    uint256 public constant MAX_BPS = 10_000;

    NodeRegistryHarness registry;

    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address unauthorized = makeAddr("unauthorized");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        registry = new NodeRegistryHarness(admin);

        vm.prank(admin);
        registry.grantRole(NODE_MANAGER_ROLE, manager);
    }

    /* ============ initial state ============ */

    function test_initialState() public view {
        assertEq(registry.maxActiveNodes(), 20);
    }

    /* ============ addNode ============ */

    function test_addNode_first() public {
        INodeRegistry.Node memory node = _getRandomNode();

        address operatorAddress = vm.randomAddress();

        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.NodeAdded(
            NODE_INCREMENT,
            operatorAddress,
            node.signingKeyPub,
            node.httpAddress,
            node.minMonthlyFeeMicroDollars
        );

        vm.prank(admin);
        uint256 nodeId = registry.addNode(
            operatorAddress,
            node.signingKeyPub,
            node.httpAddress,
            node.minMonthlyFeeMicroDollars
        );

        assertEq(nodeId, NODE_INCREMENT);

        assertEq(registry.__getOwner(nodeId), operatorAddress);

        assertEq(registry.__getNode(nodeId).signingKeyPub, node.signingKeyPub);
        assertEq(registry.__getNode(nodeId).httpAddress, node.httpAddress);
        assertEq(registry.__getNode(nodeId).inCanonicalNetwork, false);
        assertEq(registry.__getNode(nodeId).minMonthlyFeeMicroDollars, node.minMonthlyFeeMicroDollars);

        assertEq(registry.__getNodeCounter(), 1);
    }

    function test_addNode_nth() public {
        INodeRegistry.Node memory node = _getRandomNode();

        address operatorAddress = vm.randomAddress();

        registry.__setNodeCounter(11);

        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.NodeAdded(
            12 * NODE_INCREMENT,
            operatorAddress,
            node.signingKeyPub,
            node.httpAddress,
            node.minMonthlyFeeMicroDollars
        );

        vm.prank(admin);
        uint256 nodeId = registry.addNode(
            operatorAddress,
            node.signingKeyPub,
            node.httpAddress,
            node.minMonthlyFeeMicroDollars
        );

        assertEq(nodeId, 12 * NODE_INCREMENT);

        assertEq(registry.__getOwner(nodeId), operatorAddress);

        assertEq(registry.__getNode(nodeId).signingKeyPub, node.signingKeyPub);
        assertEq(registry.__getNode(nodeId).httpAddress, node.httpAddress);
        assertEq(registry.__getNode(nodeId).inCanonicalNetwork, false);
        assertEq(registry.__getNode(nodeId).minMonthlyFeeMicroDollars, node.minMonthlyFeeMicroDollars);

        assertEq(registry.__getNodeCounter(), 12);
    }

    function test_addNode_invalidAddress() public {
        INodeRegistry.Node memory node = _getRandomNode();

        vm.expectRevert(INodeRegistryErrors.InvalidAddress.selector);

        vm.prank(admin);
        registry.addNode(address(0), node.signingKeyPub, node.httpAddress, node.minMonthlyFeeMicroDollars);
    }

    function test_addNode_invalidSigningKey() public {
        INodeRegistry.Node memory node = _getRandomNode();

        vm.expectRevert(INodeRegistryErrors.InvalidSigningKey.selector);

        vm.prank(admin);
        registry.addNode(vm.randomAddress(), bytes(""), node.httpAddress, node.minMonthlyFeeMicroDollars);
    }

    function test_addNode_invalidHttpAddress() public {
        INodeRegistry.Node memory node = _getRandomNode();

        vm.expectRevert(INodeRegistryErrors.InvalidHttpAddress.selector);

        vm.prank(admin);
        registry.addNode(vm.randomAddress(), node.signingKeyPub, "", node.minMonthlyFeeMicroDollars);
    }

    function test_addNode_notAdmin() public {
        INodeRegistry.Node memory node = _getRandomNode();

        // Addresses without DEFAULT_ADMIN_ROLE cannot add registry.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.addNode(vm.randomAddress(), node.signingKeyPub, node.httpAddress, node.minMonthlyFeeMicroDollars);

        // NODE_MANAGER_ROLE is not authorized to add registry.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, manager, ADMIN_ROLE)
        );

        vm.prank(manager);
        registry.addNode(vm.randomAddress(), node.signingKeyPub, node.httpAddress, node.minMonthlyFeeMicroDollars);
    }

    /* ============ enableNode ============ */

    function test_addToNetwork() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.NodeAddedToCanonicalNetwork(1);

        vm.prank(admin);
        registry.addToNetwork(1);

        assertTrue(registry.__getNode(1).inCanonicalNetwork);
    }

    function test_addToNetwork_maxActiveNodesReached() public {
        _addNode(1, alice, "", "", false, 0);

        registry.__setMaxActiveNodes(0);

        vm.expectRevert(INodeRegistryErrors.MaxActiveNodesReached.selector);

        vm.prank(admin);
        registry.addToNetwork(1);
    }

    function test_addToNetwork_nodeDoesNotExist() public {
        vm.expectRevert(INodeRegistryErrors.NodeDoesNotExist.selector);

        vm.prank(admin);
        registry.addToNetwork(1);
    }

    function test_addToNetwork_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.addToNetwork(0);
    }

    /* ============ removeFromNetwork ============ */

    function test_removeFromNetwork() public {
        _addNode(1, alice, "", "", true, 0);

        registry.__addNodeToCanonicalNetwork(1);

        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.NodeRemovedFromCanonicalNetwork(1);

        vm.prank(admin);
        registry.removeFromNetwork(1);

        assertFalse(registry.__getNode(1).inCanonicalNetwork);
    }

    function test_removeFromNetwork_nodeDoesNotExist() public {
        vm.expectRevert(INodeRegistryErrors.NodeDoesNotExist.selector);

        vm.prank(admin);
        registry.removeFromNetwork(1);
    }

    function test_removeFromNetwork_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.removeFromNetwork(0);
    }

    /* ============ transferFrom ============ */

    function test_transferFrom() public {
        _addNode(1, alice, "", "", false, 0);
        registry.__setApproval(manager, 1, alice);

        vm.expectEmit(address(registry));
        emit IERC721.Transfer(alice, bob, 1);

        vm.prank(manager);
        registry.transferFrom(alice, bob, 1);

        assertEq(registry.ownerOf(1), bob);
    }

    function test_transferFrom_unauthorized() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                NODE_MANAGER_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.transferFrom(alice, bob, 1);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, NODE_MANAGER_ROLE)
        );

        vm.prank(alice);
        registry.transferFrom(alice, bob, 1);
    }

    function test_transferFrom_insufficientApproval() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, manager, 1));

        vm.prank(manager);
        registry.transferFrom(alice, bob, 1);
    }

    /* ============ setHttpAddress ============ */

    function test_setHttpAddress() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectEmit(address(registry));

        emit INodeRegistryEvents.HttpAddressUpdated(1, "http://example.com");

        vm.prank(manager);
        registry.setHttpAddress(1, "http://example.com");

        assertEq(registry.__getNode(1).httpAddress, "http://example.com");
    }

    function test_setHttpAddress_nodeDoesNotExist() public {
        vm.expectRevert(INodeRegistryErrors.NodeDoesNotExist.selector);

        vm.prank(manager);
        registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_invalidHttpAddress() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectRevert(INodeRegistryErrors.InvalidHttpAddress.selector);

        vm.prank(manager);
        registry.setHttpAddress(1, "");
    }

    function test_setHttpAddress_notManager() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                NODE_MANAGER_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.setHttpAddress(1, "");

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, NODE_MANAGER_ROLE)
        );

        vm.prank(alice);
        registry.setHttpAddress(1, "");
    }

    /* ============ setMinMonthlyFee ============ */

    function test_setMinMonthlyFee() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.MinMonthlyFeeUpdated(1, 1000);

        vm.prank(manager);
        registry.setMinMonthlyFee(1, 1000);

        assertEq(registry.__getNode(1).minMonthlyFeeMicroDollars, 1000);
    }

    function test_setMinMonthlyFee_nodeDoesNotExist() public {
        vm.expectRevert(INodeRegistryErrors.NodeDoesNotExist.selector);

        vm.prank(manager);
        registry.setMinMonthlyFee(1, 0);
    }

    function test_setMinMonthlyFee_notManager() public {
        _addNode(1, alice, "", "", false, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                NODE_MANAGER_ROLE
            )
        );

        vm.prank(unauthorized);
        registry.setMinMonthlyFee(0, 0);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, NODE_MANAGER_ROLE)
        );

        vm.prank(alice);
        registry.setMinMonthlyFee(0, 0);
    }

    /* ============ setMaxActiveNodes ============ */

    function test_setMaxActiveNodes() public {
        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.MaxActiveNodesUpdated(10);

        vm.prank(admin);
        registry.setMaxActiveNodes(10);

        assertEq(registry.maxActiveNodes(), 10);
    }

    function test_setMaxActiveNodes_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.setMaxActiveNodes(0);
    }

    function test_setMaxActiveNodes_lessThanActiveNodesLength() public {
        registry.__addNodeToCanonicalNetwork(1);

        vm.expectRevert(INodeRegistryErrors.MaxActiveNodesBelowCurrentCount.selector);

        vm.prank(admin);
        registry.setMaxActiveNodes(0);
    }

    /* ============ setNodeOperatorCommissionPercent ============ */

    function test_setNodeOperatorCommissionPercent() public {
        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.NodeOperatorCommissionPercentUpdated(1000);

        vm.prank(admin);
        registry.setNodeOperatorCommissionPercent(1000);

        assertEq(registry.nodeOperatorCommissionPercent(), 1000);
    }

    function test_setNodeOperatorCommissionPercent_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.setNodeOperatorCommissionPercent(0);
    }

    function test_setNodeOperatorCommissionPercent_invalidCommissionPercent() public {
        vm.expectRevert(INodeRegistryErrors.InvalidCommissionPercent.selector);

        vm.prank(admin);
        registry.setNodeOperatorCommissionPercent(MAX_BPS + 1);
    }

    /* ============ setBaseURI ============ */

    function test_setBaseURI() public {
        vm.expectEmit(address(registry));
        emit INodeRegistryEvents.BaseURIUpdated("http://example.com/");

        vm.prank(admin);
        registry.setBaseURI("http://example.com/");

        assertEq(registry.__getBaseTokenURI(), "http://example.com/");
    }

    function test_setBaseURI_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, ADMIN_ROLE)
        );

        vm.prank(unauthorized);
        registry.setBaseURI("");

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, manager, ADMIN_ROLE)
        );

        vm.prank(manager);
        registry.setBaseURI("");
    }

    function test_setBaseURI_emptyURI() public {
        vm.expectRevert(INodeRegistryErrors.InvalidURI.selector);

        vm.prank(admin);
        registry.setBaseURI("");
    }

    function test_setBaseURI_noTrailingSlash() public {
        vm.expectRevert(INodeRegistryErrors.InvalidURI.selector);

        vm.prank(admin);
        registry.setBaseURI("http://example.com");
    }

    /* ============ getAllNodes ============ */

    function test_getAllNodes() public {
        INodeRegistry.NodeWithId[] memory allNodes;

        _addNode(NODE_INCREMENT, alice, "", "", false, 0);
        registry.__setNodeCounter(1);

        allNodes = registry.getAllNodes();

        assertEq(allNodes.length, 1);
        assertEq(allNodes[0].nodeId, NODE_INCREMENT);

        _addNode(NODE_INCREMENT * 2, alice, "", "", false, 0);
        registry.__setNodeCounter(2);

        allNodes = registry.getAllNodes();

        assertEq(allNodes.length, 2);
        assertEq(allNodes[0].nodeId, NODE_INCREMENT);
        assertEq(allNodes[1].nodeId, NODE_INCREMENT * 2);
    }

    /* ============ getAllNodesCount ============ */

    function test_getAllNodesCount() public {
        registry.__setNodeCounter(1);

        assertEq(registry.getAllNodesCount(), 1);

        registry.__setNodeCounter(2);

        assertEq(registry.getAllNodesCount(), 2);
    }

    /* ============ getNode ============ */

    function test_getNode() public {
        _addNode(1, alice, hex"1F1F1F", "httpAddress", true, 1000);

        INodeRegistry.Node memory node = registry.__getNode(1);

        assertEq(node.signingKeyPub, hex"1F1F1F");
        assertEq(node.httpAddress, "httpAddress");
        assertEq(node.minMonthlyFeeMicroDollars, 1000);
    }

    function test_getNode_nodeDoesNotExist() public {
        vm.expectRevert(INodeRegistryErrors.NodeDoesNotExist.selector);
        registry.getNode(1);
    }

    /* ============ supportsInterface ============ */

    function test_supportsInterface() public view {
        assertTrue(registry.supportsInterface(type(IERC721).interfaceId));
        assertTrue(registry.supportsInterface(type(IERC165).interfaceId));
        assertTrue(registry.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(registry.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
    }

    /* ============ revokeRole ============ */

    function test_revokeRole_revokeDefaultAdminRole() public {
        vm.expectRevert(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector);
        registry.revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /* ============ renounceRole ============ */

    function test_renounceRole_withinDelay() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, 0)
        );

        registry.renounceRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /* ============ helper functions ============ */

    function _addNode(
        uint256 nodeId,
        address nodeOperator,
        bytes memory signingKeyPub,
        string memory httpAddress,
        bool inCanonicalNetwork,
        uint256 minMonthlyFeeMicroDollars
    ) internal {
        registry.__setNode(nodeId, signingKeyPub, httpAddress, inCanonicalNetwork, minMonthlyFeeMicroDollars);
        registry.__mint(nodeOperator, nodeId);
    }

    function _getRandomNode() internal view returns (INodeRegistry.Node memory) {
        return
            INodeRegistry.Node({
                signingKeyPub: _genBytes(32),
                httpAddress: _genString(32),
                inCanonicalNetwork: false,
                minMonthlyFeeMicroDollars: _genRandomInt(100, 10_000)
            });
    }
}
