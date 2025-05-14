// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { SequentialMerkleProofs } from "../../src/libraries/SequentialMerkleProofs.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { PayerReportManagerHarness } from "../utils/Harnesses.sol";

import {
    MockParameterRegistry,
    MockNodeRegistry,
    MockPayerRegistry,
    MockMigrator,
    MockFailingMigrator
} from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract PayerReportManagerTests is Test {
    bytes32 internal constant _EIP712_DOMAIN_HASH =
        keccak256(
            abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );

    bytes internal constant _MIGRATOR_KEY = "xmtp.payerReportManager.migrator";

    PayerReportManagerHarness internal _manager;

    address internal _implementation;
    address internal _parameterRegistry;
    address internal _nodeRegistry;
    address internal _payerRegistry;

    address internal _signer1;
    uint256 internal _signer1Pk;
    address internal _signer2;
    uint256 internal _signer2Pk;
    address internal _signer3;
    uint256 internal _signer3Pk;
    address internal _signer4;
    uint256 internal _signer4Pk;

    function setUp() external {
        (_signer1, _signer1Pk) = makeAddrAndKey("signer1");
        (_signer2, _signer2Pk) = makeAddrAndKey("signer2");
        (_signer3, _signer3Pk) = makeAddrAndKey("signer3");
        (_signer4, _signer4Pk) = makeAddrAndKey("signer4");

        _parameterRegistry = address(new MockParameterRegistry());
        _nodeRegistry = address(new MockNodeRegistry());
        _payerRegistry = address(new MockPayerRegistry());

        _implementation = address(new PayerReportManagerHarness(_parameterRegistry, _nodeRegistry, _payerRegistry));

        _manager = PayerReportManagerHarness(address(new Proxy(_implementation)));

        _manager.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IPayerReportManager.ZeroParameterRegistry.selector);
        new PayerReportManagerHarness(address(0), address(0), address(0));
    }

    function test_constructor_zeroNodeRegistry() external {
        vm.expectRevert(IPayerReportManager.ZeroNodeRegistry.selector);
        new PayerReportManagerHarness(_parameterRegistry, address(0), address(0));
    }

    function test_constructor_zeroPayerRegistry() external {
        vm.expectRevert(IPayerReportManager.ZeroPayerRegistry.selector);
        new PayerReportManagerHarness(_parameterRegistry, _nodeRegistry, address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_manager)), _implementation);
        assertEq(_manager.implementation(), _implementation);
        assertEq(_manager.parameterRegistry(), _parameterRegistry);
        assertEq(_manager.nodeRegistry(), _nodeRegistry);
        assertEq(_manager.payerRegistry(), _payerRegistry);
        assertEq(_manager.migratorParameterKey(), _MIGRATOR_KEY);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _manager.initialize();
    }

    /* ============ submit ============ */

    function test_submit_invalidStartSequenceId() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 10,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InvalidStartSequenceId.selector, 11, 10));

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 11,
            endSequenceId_: 11,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_submit_invalidSequenceIds() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 10,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(IPayerReportManager.InvalidSequenceIds.selector);

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 10,
            endSequenceId_: 9,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_submit_unorderedNodeIds() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: "" });
        signatures_[1] = IPayerReportManager.PayerReportSignature({ nodeId: 0, signature: "" });

        vm.expectRevert(IPayerReportManager.UnorderedNodeIds.selector);

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });
    }

    function test_submit_insufficientSignatures() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            1
        );

        bytes memory signature_ = _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer1Pk);

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: signature_ });

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1), abi.encode(true));
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(3));

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InsufficientSignatures.selector, 1, 2));

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });
    }

    function test_submit_zeroPayersMerkleRoot() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0)
        });

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            3
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(0), new uint32[](0), _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(0), new uint32[](0), _signer2Pk)
        });

        signatures_[2] = IPayerReportManager.PayerReportSignature({
            nodeId: 3,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(0), new uint32[](0), _signer3Pk)
        });

        uint32[] memory validSigningNodeIds_ = new uint32[](2);

        validSigningNodeIds_[0] = 1;
        validSigningNodeIds_[1] = 2;

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 2), abi.encode(_signer2));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 3),
            abi.encode(false)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(3));

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubmitted({
            originatorNodeId: 0,
            payerReportIndex: 1,
            startSequenceId: 1,
            endSequenceId: 2,
            payersMerkleRoot: bytes32(0),
            nodeIds: new uint32[](0),
            signingNodeIds: validSigningNodeIds_
        });

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 1, 0, 0, 0);

        uint256 payerReportIndex_ = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 1,
            endSequenceId_: 2,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });

        assertEq(payerReportIndex_, 1);

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(0, 1);

        assertEq(payerReport_.startSequenceId, 1);
        assertEq(payerReport_.endSequenceId, 2);
        assertEq(payerReport_.feesSettled, 0);
        assertEq(payerReport_.offset, 0);
        assertTrue(payerReport_.isSettled);
        assertEq(payerReport_.payersMerkleRoot, bytes32(0));
        assertEq(payerReport_.nodeIds.length, 0);
    }

    function test_submit() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0)
        });

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            3
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(uint256(1)), new uint32[](0), _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(uint256(1)), new uint32[](0), _signer2Pk)
        });

        signatures_[2] = IPayerReportManager.PayerReportSignature({
            nodeId: 3,
            signature: _getPayerReportSignature(0, 1, 2, bytes32(uint256(1)), new uint32[](0), _signer3Pk)
        });

        uint32[] memory validSigningNodeIds_ = new uint32[](2);

        validSigningNodeIds_[0] = 1;
        validSigningNodeIds_[1] = 2;

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 2), abi.encode(_signer2));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 3),
            abi.encode(false)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(3));

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubmitted({
            originatorNodeId: 0,
            payerReportIndex: 1,
            startSequenceId: 1,
            endSequenceId: 2,
            payersMerkleRoot: bytes32(uint256(1)),
            nodeIds: new uint32[](0),
            signingNodeIds: validSigningNodeIds_
        });

        uint256 payerReportIndex_ = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 1,
            endSequenceId_: 2,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });

        assertEq(payerReportIndex_, 1);

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(0, 1);

        assertEq(payerReport_.startSequenceId, 1);
        assertEq(payerReport_.endSequenceId, 2);
        assertEq(payerReport_.feesSettled, 0);
        assertEq(payerReport_.offset, 0);
        assertFalse(payerReport_.isSettled);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(1)));
        assertEq(payerReport_.nodeIds.length, 0);
    }

    /* ============ settle ============ */

    function test_settle_payerReportIndexOutOfBounds() external {
        vm.expectRevert(IPayerReportManager.PayerReportIndexOutOfBounds.selector);
        _manager.settle(0, 0, new bytes[](0), new bytes32[](0));
    }

    function test_settle_payerReportEntirelySettled() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: true,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(IPayerReportManager.PayerReportEntirelySettled.selector);
        _manager.settle(0, 0, new bytes[](0), new bytes32[](0));
    }

    function test_settle_invalidProof() external {
        // This is the root for the payer fees: (1, 100), (2, 200), (3, 300), (4, 400), (5, 500), (6, 600).
        bytes32 payersMerkleRoot_ = 0xf3051bbf3818e5393ac18edd8ba285e62f35fe01748a8acc900eca813a6b364e;

        bytes[] memory payerFees_ = new bytes[](3);
        payerFees_[0] = abi.encode(address(1), uint96(100));
        payerFees_[1] = abi.encode(address(2), uint96(200));
        payerFees_[2] = abi.encode(address(3), uint96(300));

        bytes32[] memory proofElements_ = new bytes32[](3);

        // Incorrect leaf count as first proof element.
        proofElements_[0] = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000005));
        proofElements_[1] = bytes32(0xbf3990232dba4985267c2b0c64d09165457aa9bc02292fff8416821335f719ad);
        proofElements_[2] = bytes32(0x179a5ab6250bc7b598e955bb7a59ed2b26171140d0c9ecbdb5e2ee15a529dfc5);

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(SequentialMerkleProofs.InvalidProof.selector);
        _manager.settle(0, 0, payerFees_, proofElements_);
    }

    function test_settle_settleUsageFailed() external {
        // This is the root for the payer fees: (1, 100), (2, 200), (3, 300), (4, 400), (5, 500), (6, 600).
        bytes32 payersMerkleRoot_ = 0xf3051bbf3818e5393ac18edd8ba285e62f35fe01748a8acc900eca813a6b364e;

        bytes[] memory payerFees_ = new bytes[](3);
        payerFees_[0] = abi.encode(address(1), uint96(100));
        payerFees_[1] = abi.encode(address(2), uint96(200));
        payerFees_[2] = abi.encode(address(3), uint96(300));

        bytes32[] memory proofElements_ = new bytes32[](3);
        proofElements_[0] = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000006));
        proofElements_[1] = bytes32(0xbf3990232dba4985267c2b0c64d09165457aa9bc02292fff8416821335f719ad);
        proofElements_[2] = bytes32(0x179a5ab6250bc7b598e955bb7a59ed2b26171140d0c9ecbdb5e2ee15a529dfc5);

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        vm.mockCallRevert(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage((address,uint96)[])", payerFees_),
            "Test Failure"
        );

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.SettleUsageFailed.selector, "Test Failure"));
        _manager.settle(0, 0, payerFees_, proofElements_);
    }

    function test_settle_firstHalf() external {
        // This is the root for the payer fees: (1, 100), (2, 200), (3, 300), (4, 400), (5, 500), (6, 600).
        bytes32 payersMerkleRoot_ = 0xf3051bbf3818e5393ac18edd8ba285e62f35fe01748a8acc900eca813a6b364e;

        bytes[] memory payerFees_ = new bytes[](3);
        payerFees_[0] = abi.encode(address(1), uint96(100));
        payerFees_[1] = abi.encode(address(2), uint96(200));
        payerFees_[2] = abi.encode(address(3), uint96(300));

        bytes32[] memory proofElements_ = new bytes32[](3);
        proofElements_[0] = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000006));
        proofElements_[1] = bytes32(0xbf3990232dba4985267c2b0c64d09165457aa9bc02292fff8416821335f719ad);
        proofElements_[2] = bytes32(0x179a5ab6250bc7b598e955bb7a59ed2b26171140d0c9ecbdb5e2ee15a529dfc5);

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage((address,uint96)[])", payerFees_),
            abi.encode(uint96(600))
        );

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 0, 3, 3, 600);

        _manager.settle(0, 0, payerFees_, proofElements_);

        assertEq(_manager.getPayerReport(0, 0).feesSettled, 600);
        assertEq(_manager.getPayerReport(0, 0).offset, 3);
    }

    function test_settle_secondHalf() external {
        // This is the root for the payer fees: (1, 100), (2, 200), (3, 300), (4, 400), (5, 500), (6, 600).
        bytes32 payersMerkleRoot_ = 0xf3051bbf3818e5393ac18edd8ba285e62f35fe01748a8acc900eca813a6b364e;

        bytes[] memory payerFees_ = new bytes[](3);
        payerFees_[0] = abi.encode(address(4), uint96(400));
        payerFees_[1] = abi.encode(address(5), uint96(500));
        payerFees_[2] = abi.encode(address(6), uint96(600));

        bytes32[] memory proofElements_ = new bytes32[](3);
        proofElements_[0] = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000006));
        proofElements_[1] = bytes32(0xe1fd91200025ec7e94c96c4e035820e7f510e94f479b07caf2791ed8991d80ca);
        proofElements_[2] = bytes32(0x81c8c090425d4a46672a976619a2dd2fce8b9b0fea5e01d1fb32e78bff1681d0);

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 600,
            offset_: 3,
            isSettled_: false,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage((address,uint96)[])", payerFees_),
            abi.encode(uint96(1_500))
        );

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 0, 3, 0, 1_500);

        _manager.settle(0, 0, payerFees_, proofElements_);

        assertEq(_manager.getPayerReport(0, 0).feesSettled, 600 + 1_500);
        assertEq(_manager.getPayerReport(0, 0).offset, 6);
        assertTrue(_manager.getPayerReport(0, 0).isSettled);
    }

    function test_settle_oneShot() external {
        // This is the root for the payer fees: (1, 100), (2, 200), (3, 300), (4, 400), (5, 500), (6, 600).
        bytes32 payersMerkleRoot_ = 0xf3051bbf3818e5393ac18edd8ba285e62f35fe01748a8acc900eca813a6b364e;

        bytes[] memory payerFees_ = new bytes[](6);
        payerFees_[0] = abi.encode(address(1), uint96(100));
        payerFees_[1] = abi.encode(address(2), uint96(200));
        payerFees_[2] = abi.encode(address(3), uint96(300));
        payerFees_[3] = abi.encode(address(4), uint96(400));
        payerFees_[4] = abi.encode(address(5), uint96(500));
        payerFees_[5] = abi.encode(address(6), uint96(600));

        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000006));

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage((address,uint96)[])", payerFees_),
            abi.encode(uint96(2_100))
        );

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 0, 6, 0, 2_100);

        _manager.settle(0, 0, payerFees_, proofElements_);

        assertEq(_manager.getPayerReport(0, 0).feesSettled, 2_100);
        assertEq(_manager.getPayerReport(0, 0).offset, 6);
        assertTrue(_manager.getPayerReport(0, 0).isSettled);
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _manager.migrate();
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

        _manager.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryCall(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _manager.migrate();
    }

    function test_migrate() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            payersMerkleRoot_: bytes32(uint256(6)),
            nodeIds_: new uint32[](7)
        });

        address newImplementation_ = address(
            new PayerReportManagerHarness(_parameterRegistry, _nodeRegistry, _payerRegistry)
        );

        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_manager));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_manager));
        emit IERC1967.Upgraded(newImplementation_);

        _manager.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_manager)), newImplementation_);
        assertEq(_manager.parameterRegistry(), _parameterRegistry);

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(1, 0);

        assertEq(payerReport_.startSequenceId, 2);
        assertEq(payerReport_.endSequenceId, 3);
        assertEq(payerReport_.feesSettled, 4);
        assertEq(payerReport_.offset, 5);
        assertTrue(payerReport_.isSettled);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(6)));
        assertEq(payerReport_.nodeIds.length, 7);
    }

    /* ============ _verifySignatures ============ */

    function test_internal_verifySignatures_unorderedNodeIds() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: "" });
        signatures_[1] = IPayerReportManager.PayerReportSignature({ nodeId: 0, signature: "" });

        vm.expectRevert(IPayerReportManager.UnorderedNodeIds.selector);

        _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });
    }

    function test_internal_verifySignatures_insufficientSignatures() external {
        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InsufficientSignatures.selector, 0, 1));

        _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_internal_verifySignatures_lastInvalid() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            3
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer2Pk)
        });

        signatures_[2] = IPayerReportManager.PayerReportSignature({
            nodeId: 3,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer3Pk)
        });

        uint32[] memory expectedValidSigningNodeIds_ = new uint32[](2);

        expectedValidSigningNodeIds_[0] = 1;
        expectedValidSigningNodeIds_[1] = 2;

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 2), abi.encode(_signer2));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 3),
            abi.encode(false)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(3));

        uint32[] memory validSigningNodeIds_ = _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });

        assertEq(validSigningNodeIds_.length, 2);

        assertEq(validSigningNodeIds_[0], 1);
        assertEq(validSigningNodeIds_[1], 2);
    }

    function test_internal_verifySignatures_middleInvalid() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            3
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer2Pk)
        });

        signatures_[2] = IPayerReportManager.PayerReportSignature({
            nodeId: 3,
            signature: _getPayerReportSignature(0, 0, 0, bytes32(0), new uint32[](0), _signer3Pk)
        });

        uint32[] memory expectedValidSigningNodeIds_ = new uint32[](2);

        expectedValidSigningNodeIds_[0] = 1;
        expectedValidSigningNodeIds_[1] = 3;

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 2),
            abi.encode(false)
        );

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 3),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 3), abi.encode(_signer3));

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(3));

        uint32[] memory validSigningNodeIds_ = _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });

        assertEq(validSigningNodeIds_.length, 2);

        assertEq(validSigningNodeIds_[0], 1);
        assertEq(validSigningNodeIds_[1], 3);
    }

    /* ============ _verifySignature ============ */

    function test_internal_verifySignature_notCanonicalNode() external {
        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(false)
        );

        assertFalse(_manager.__verifySignature(bytes32(0), 1, ""));
    }

    function test_internal_verifySignature_invalidSignature() external {
        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        assertFalse(_manager.__verifySignature(bytes32(0), 1, ""));
    }

    function test_internal_verifySignature_notNodeOwner() external {
        bytes memory signature_ = _getPayerReportSignature({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            payersMerkleRoot_: bytes32(0),
            nodeIds_: new uint32[](0),
            privateKey_: _signer1Pk
        });

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        assertFalse(_manager.__verifySignature(bytes32(0), 1, signature_));
    }

    function test_internal_verifySignature() external {
        bytes memory signature_ = _getSignature(bytes32(0), _signer1Pk);

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        assertTrue(_manager.__verifySignature(bytes32(0), 1, signature_));
    }

    /* ============ getPayerReportDigest ============ */

    function test_getPayerReportDigest() external view {
        assertEq(
            _manager.getPayerReportDigest({
                originatorNodeId_: 1,
                startSequenceId_: 2,
                endSequenceId_: 3,
                payersMerkleRoot_: bytes32(uint256(4)),
                nodeIds_: new uint32[](5)
            }),
            0xbf09bdaeb24a76f0ab947a527805ba9f56f22462ac91d9db03ef4b230c3aca4d
        );

        assertEq(
            _manager.getPayerReportDigest({
                originatorNodeId_: 10,
                startSequenceId_: 20,
                endSequenceId_: 30,
                payersMerkleRoot_: bytes32(uint256(40)),
                nodeIds_: new uint32[](50)
            }),
            0x1b7e79d4dcb404edf32daa7431199f901b2403392e088812287e16e26b112b6c
        );
    }

    /* ============ getPayerReports ============ */

    function test_getPayerReports_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.ArrayLengthMismatch.selector));
        _manager.getPayerReports(new uint32[](1), new uint256[](2));
    }

    function test_getPayerReports() external {
        uint32[] memory nodeIds_ = new uint32[](7);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            payersMerkleRoot_: bytes32(uint256(6)),
            nodeIds_: nodeIds_
        });

        _manager.__pushPayerReport({
            originatorNodeId_: 10,
            startSequenceId_: 20,
            endSequenceId_: 30,
            feesSettled_: 40,
            offset_: 50,
            isSettled_: true,
            payersMerkleRoot_: bytes32(uint256(60)),
            nodeIds_: nodeIds_
        });

        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 1;
        originatorNodeIds_[1] = 10;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        IPayerReportManager.PayerReport[] memory payerReports_ = _manager.getPayerReports(
            originatorNodeIds_,
            payerReportIndices_
        );

        assertEq(payerReports_.length, 2);

        assertEq(payerReports_[0].startSequenceId, 2);
        assertEq(payerReports_[0].endSequenceId, 3);
        assertEq(payerReports_[0].feesSettled, 4);
        assertEq(payerReports_[0].offset, 5);
        assertTrue(payerReports_[0].isSettled);
        assertEq(payerReports_[0].payersMerkleRoot, bytes32(uint256(6)));
        assertEq(payerReports_[0].nodeIds.length, 7);

        assertEq(payerReports_[1].startSequenceId, 20);
        assertEq(payerReports_[1].endSequenceId, 30);
        assertEq(payerReports_[1].feesSettled, 40);
        assertEq(payerReports_[1].offset, 50);
        assertTrue(payerReports_[1].isSettled);
        assertEq(payerReports_[1].payersMerkleRoot, bytes32(uint256(60)));
        assertEq(payerReports_[1].nodeIds.length, 7);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReports_[0].nodeIds[index_], 10 + index_);
        }

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReports_[1].nodeIds[index_], 10 + index_);
        }
    }

    /* ============ getPayerReport ============ */

    function test_getPayerReport() external {
        uint32[] memory nodeIds_ = new uint32[](7);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            payersMerkleRoot_: bytes32(uint256(6)),
            nodeIds_: nodeIds_
        });

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(1, 0);

        assertEq(payerReport_.startSequenceId, 2);
        assertEq(payerReport_.endSequenceId, 3);
        assertEq(payerReport_.feesSettled, 4);
        assertEq(payerReport_.offset, 5);
        assertTrue(payerReport_.isSettled);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(6)));
        assertEq(payerReport_.nodeIds.length, 7);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReport_.nodeIds[index_], 10 + index_);
        }
    }

    /* ============ DOMAIN_SEPARATOR ============ */

    function test_DOMAIN_SEPARATOR() external view {
        assertEq(
            _manager.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    _EIP712_DOMAIN_HASH,
                    keccak256(bytes("PayerReportManager")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(_manager)
                )
            )
        );
    }

    /* ============ PAYER_REPORT_TYPEHASH ============ */

    function test_PAYER_REPORT_TYPEHASH() external view {
        assertEq(
            _manager.PAYER_REPORT_TYPEHASH(),
            keccak256(
                "PayerReport(uint32 originatorNodeId,uint32 startSequenceId,uint32 endSequenceId,bytes32 payersMerkleRoot,uint32[] nodeIds)"
            )
        );
    }

    /* ============ eip712Domain ============ */

    function test_eip712Domain() external view {
        (
            bytes1 fields_,
            string memory name_,
            string memory version_,
            uint256 chainId_,
            address verifyingContract_,
            bytes32 salt_,
            uint256[] memory extensions_
        ) = _manager.eip712Domain();

        assertEq(fields_, hex"0f");
        assertEq(name_, "PayerReportManager");
        assertEq(version_, "1");
        assertEq(chainId_, block.chainid);
        assertEq(verifyingContract_, address(_manager));
        assertEq(salt_, bytes32(0));
        assertEq(extensions_.length, 0);
    }

    /* ============ helper functions ============ */

    function _getPayerReportSignature(
        uint32 originatorNodeId_,
        uint32 startSequenceId_,
        uint32 endSequenceId_,
        bytes32 payersMerkleRoot_,
        uint32[] memory nodeIds_,
        uint256 privateKey_
    ) internal view returns (bytes memory signature_) {
        return
            _getSignature(
                _manager.getPayerReportDigest(
                    originatorNodeId_,
                    startSequenceId_,
                    endSequenceId_,
                    payersMerkleRoot_,
                    nodeIds_
                ),
                privateKey_
            );
    }

    function _getSignature(bytes32 digest_, uint256 privateKey_) internal pure returns (bytes memory signature_) {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(privateKey_, digest_);

        return abi.encodePacked(r_, s_, v_);
    }
}
