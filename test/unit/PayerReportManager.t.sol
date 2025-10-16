// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";
import { ISequentialMerkleProofsErrors } from "../../src/libraries/interfaces/ISequentialMerkleProofsErrors.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { PayerReportManagerHarness } from "../utils/Harnesses.sol";

import { MockMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract PayerReportManagerTests is Test {
    bytes32 internal constant _EIP712_DOMAIN_HASH =
        keccak256(
            abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );

    string internal constant _MIGRATOR_KEY = "xmtp.payerReportManager.migrator";
    string internal constant _PROTOCOL_FEE_RATE_KEY = "xmtp.payerReportManager.protocolFeeRate";

    PayerReportManagerHarness internal _manager;

    address internal _implementation;

    address internal _nodeRegistry = makeAddr("nodeRegistry");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _payerRegistry = makeAddr("payerRegistry");

    address internal _signer1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal _signer2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal _signer3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal _signer4 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 internal _signer1Pk = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
    uint256 internal _signer2Pk = uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
    uint256 internal _signer3Pk = uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a);
    uint256 internal _signer4Pk = uint256(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);

    function setUp() external {
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
        assertEq(_manager.protocolFeeRateParameterKey(), _PROTOCOL_FEE_RATE_KEY);
        assertEq(_manager.ONE_HUNDRED_PERCENT(), 10_000);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _manager.initialize();
    }

    /* ============ submit ============ */

    function test_submit_payerReportAlreadySubmitted() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.PayerReportAlreadySubmitted.selector, 0, 0, 1));

        uint256 payerReportIndex_ = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_submit_invalidStartSequenceId() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 10,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InvalidStartSequenceId.selector, 11, 10));

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 11,
            endSequenceId_: 11,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_submit_invalidSequenceIds() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 10,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(IPayerReportManager.InvalidSequenceIds.selector);

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 10,
            endSequenceId_: 9,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    function test_submit_unorderedNodeIds() external {
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](3);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({
                signer: address(0xA1),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({
                signer: address(0xA2),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: "" });
        signatures_[1] = IPayerReportManager.PayerReportSignature({ nodeId: 0, signature: "" });

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1), abi.encode(false));

        vm.expectRevert(IPayerReportManager.UnorderedNodeIds.selector);

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });
    }

    function test_submit_insufficientSignatures() external {
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](3);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({
                signer: address(0xA1),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({
                signer: address(0xA2),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );
        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            1
        );

        bytes memory signature_ = _getPayerReportSignature(0, 0, 0, 0, 0, nodeIds_, _signer1Pk);

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: signature_ });

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InsufficientSignatures.selector, 1, 2));

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });
    }

    function test_submit_zeroPayersMerkleRoot() external {
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](3);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({
                signer: address(0xA1),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({
                signer: address(0xA2),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_
        });

        _manager.__setProtocolFeeRate(100);

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 1, 2, 0, 0, nodeIds_, _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 1, 2, 0, 0, nodeIds_, _signer2Pk)
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

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubmitted({
            originatorNodeId: 0,
            payerReportIndex: 1,
            startSequenceId: 1,
            endSequenceId: 2,
            endMinuteSinceEpoch: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_,
            signingNodeIds: validSigningNodeIds_
        });

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 1, 0, 0, 0);

        uint256 payerReportIndex_ = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 1,
            endSequenceId_: 2,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });

        assertEq(payerReportIndex_, 1);

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(0, 1);

        assertEq(payerReport_.startSequenceId, 1);
        assertEq(payerReport_.endSequenceId, 2);
        assertEq(payerReport_.feesSettled, 0);
        assertEq(payerReport_.offset, 0);
        assertTrue(payerReport_.isSettled);
        assertEq(payerReport_.protocolFeeRate, 100);
        assertEq(payerReport_.payersMerkleRoot, 0);
        assertEq(payerReport_.nodeIds.length, 3);
    }

    function test_submit_complete() external {
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](3);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({
                signer: address(0xA1),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({
                signer: address(0xA2),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        _manager.__pushPayerReport({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 1,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_
        });

        _manager.__setProtocolFeeRate(100);

        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({
            nodeId: 1,
            signature: _getPayerReportSignature(0, 1, 2, 0, bytes32(uint256(1)), nodeIds_, _signer1Pk)
        });

        signatures_[1] = IPayerReportManager.PayerReportSignature({
            nodeId: 2,
            signature: _getPayerReportSignature(0, 1, 2, 0, bytes32(uint256(1)), nodeIds_, _signer2Pk)
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

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubmitted({
            originatorNodeId: 0,
            payerReportIndex: 1,
            startSequenceId: 1,
            endSequenceId: 2,
            endMinuteSinceEpoch: 0,
            payersMerkleRoot: bytes32(uint256(1)),
            nodeIds: nodeIds_,
            signingNodeIds: validSigningNodeIds_
        });

        uint256 payerReportIndex_ = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 1,
            endSequenceId_: 2,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });

        assertEq(payerReportIndex_, 1);

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(0, 1);

        assertEq(payerReport_.startSequenceId, 1);
        assertEq(payerReport_.endSequenceId, 2);
        assertEq(payerReport_.feesSettled, 0);
        assertEq(payerReport_.offset, 0);
        assertFalse(payerReport_.isSettled);
        assertEq(payerReport_.protocolFeeRate, 100);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(1)));
        assertEq(payerReport_.nodeIds.length, 3);
    }

    function test_submit_reverts_when_nodeIds_do_not_match_canonical_set() external {
        // Registry snapshot:
        //  id=1 (canonical), id=2 (canonical), id=3 (non-canonical), id=4 (canonical)
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](4);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({
                signer: address(0xA1),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({
                signer: address(0xA2),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: false,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[3] = INodeRegistry.NodeWithId({
            nodeId: 4,
            node: INodeRegistry.Node({
                signer: address(0xA4),
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        // Submit an incorrect canonical list (length mismatch here)
        uint32[] memory nodeIds_ = new uint32[](2);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;

        // Signatures won’t be reached because we expect an early revert
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            0
        );

        vm.expectRevert(
            abi.encodeWithSelector(IPayerReportManager.NodeIdsLengthMismatch.selector, uint32(3), uint32(2))
        );

        _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0, // ok for first report
            endSequenceId_: 10,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });
    }

    function test_submit_accepts_when_nodeIds_equal_canonical_set_even_with_noncano_present() external {
        // Registry snapshot:
        //  id=1 (canonical), id=2 (canonical), id=3 (non-canonical), id=4 (canonical)
        INodeRegistry.NodeWithId[] memory all_ = new INodeRegistry.NodeWithId[](4);
        all_[0] = INodeRegistry.NodeWithId({
            nodeId: 1,
            node: INodeRegistry.Node({ signer: _signer1, isCanonical: true, signingPublicKey: "", httpAddress: "" })
        });
        all_[1] = INodeRegistry.NodeWithId({
            nodeId: 2,
            node: INodeRegistry.Node({ signer: _signer2, isCanonical: true, signingPublicKey: "", httpAddress: "" })
        });
        all_[2] = INodeRegistry.NodeWithId({
            nodeId: 3,
            node: INodeRegistry.Node({
                signer: address(0xA3),
                isCanonical: false,
                signingPublicKey: "",
                httpAddress: ""
            })
        });
        all_[3] = INodeRegistry.NodeWithId({
            nodeId: 4,
            node: INodeRegistry.Node({
                signer: _signer3, // canonical signer for id=4
                isCanonical: true,
                signingPublicKey: "",
                httpAddress: ""
            })
        });

        // Mock registry calls used by _enforceNodeIdsMatchCanonicalRegistry
        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getAllNodes()"), abi.encode(all_));

        // The submitted set must be exactly the canonical set (sorted strictly increasing)
        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 4;

        // Two valid signatures (quorum for 3 canonicals is (3/2)+1 = 2)
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        bytes memory sig1_ = _getPayerReportSignature(0, 0, 10, 0, bytes32(uint256(1)), nodeIds_, _signer1Pk);
        bytes memory sig2_ = _getPayerReportSignature(0, 0, 10, 0, bytes32(uint256(1)), nodeIds_, _signer2Pk);

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: sig1_ });
        signatures_[1] = IPayerReportManager.PayerReportSignature({ nodeId: 2, signature: sig2_ });

        // Mocks used by __verifySignature for signers 1 and 2
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

        // Submit succeeds; returns index 0 (first report for originator 0)
        uint256 idx = _manager.submit({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 10,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: bytes32(uint256(1)),
            nodeIds_: nodeIds_,
            signatures_: signatures_
        });

        assertEq(idx, 0);

        IPayerReportManager.PayerReport memory pr = _manager.getPayerReport(0, 0);
        assertEq(pr.startSequenceId, 0);
        assertEq(pr.endSequenceId, 10);
        assertEq(pr.nodeIds.length, 3);
        assertEq(pr.nodeIds[0], 1);
        assertEq(pr.nodeIds[1], 2);
        assertEq(pr.nodeIds[2], 4);
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: true,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        vm.expectRevert(ISequentialMerkleProofsErrors.InvalidProof.selector);
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        bytes32 digest_ = _manager.__getPayerReportDigest(0, 0, 0, 0, payersMerkleRoot_, new uint32[](0));

        vm.mockCallRevert(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage(bytes32,(address,uint96)[])", digest_, payerFees_),
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        bytes32 digest_ = _manager.__getPayerReportDigest(0, 0, 0, 0, payersMerkleRoot_, new uint32[](0));

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage(bytes32,(address,uint96)[])", digest_, payerFees_),
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 600,
            offset_: 3,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        bytes32 digest_ = _manager.__getPayerReportDigest(0, 0, 0, 0, payersMerkleRoot_, new uint32[](0));

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage(bytes32,(address,uint96)[])", digest_, payerFees_),
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
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: payersMerkleRoot_,
            nodeIds_: new uint32[](0)
        });

        bytes32 digest_ = _manager.__getPayerReportDigest(0, 0, 0, 0, payersMerkleRoot_, new uint32[](0));

        Utils.expectAndMockCall(
            _payerRegistry,
            abi.encodeWithSignature("settleUsage(bytes32,(address,uint96)[])", digest_, payerFees_),
            abi.encode(uint96(2_100))
        );

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.PayerReportSubsetSettled(0, 0, 6, 0, 2_100);

        _manager.settle(0, 0, payerFees_, proofElements_);

        assertEq(_manager.getPayerReport(0, 0).feesSettled, 2_100);
        assertEq(_manager.getPayerReport(0, 0).offset, 6);
        assertTrue(_manager.getPayerReport(0, 0).isSettled);
    }

    /* ============ updateProtocolFeeRate ============ */

    function test_updateProtocolFeeRate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PROTOCOL_FEE_RATE_KEY,
            bytes32(uint256(type(uint16).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _manager.updateProtocolFeeRate();
    }

    function test_updateProtocolFeeRate_invalidProtocolFeeRate() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PROTOCOL_FEE_RATE_KEY, bytes32(uint256(10_001)));

        vm.expectRevert(IPayerReportManager.InvalidProtocolFeeRate.selector);

        _manager.updateProtocolFeeRate();
    }

    function test_updateProtocolFeeRate_noChange() external {
        _manager.__setProtocolFeeRate(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PROTOCOL_FEE_RATE_KEY, bytes32(uint256(100)));

        vm.expectRevert(IPayerReportManager.NoChange.selector);

        _manager.updateProtocolFeeRate();
    }

    function test_updateProtocolFeeRate() external {
        _manager.__setProtocolFeeRate(100);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PROTOCOL_FEE_RATE_KEY, bytes32(uint256(200)));

        vm.expectEmit(address(_manager));
        emit IPayerReportManager.ProtocolFeeRateUpdated(200);

        _manager.updateProtocolFeeRate();

        assertEq(_manager.protocolFeeRate(), 200);
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _manager.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _manager.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = makeAddr("migrator");

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        bytes memory revertData_ = abi.encodeWithSignature("Failed()");

        vm.mockCallRevert(migrator_, bytes(""), revertData_);

        vm.expectRevert(abi.encodeWithSelector(IMigratable.MigrationFailed.selector, migrator_, revertData_));

        _manager.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _manager.migrate();
    }

    function test_migrate() external {
        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            protocolFeeRate_: 6,
            payersMerkleRoot_: bytes32(uint256(7)),
            nodeIds_: new uint32[](8)
        });

        address newImplementation_ = address(
            new PayerReportManagerHarness(_parameterRegistry, _nodeRegistry, _payerRegistry)
        );

        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
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
        assertEq(payerReport_.protocolFeeRate, 6);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(7)));
        assertEq(payerReport_.nodeIds.length, 8);
    }

    /* ============ _verifySignatures ============ */

    function test_internal_verifySignatures_unorderedNodeIds() external {
        IPayerReportManager.PayerReportSignature[] memory signatures_ = new IPayerReportManager.PayerReportSignature[](
            2
        );

        signatures_[0] = IPayerReportManager.PayerReportSignature({ nodeId: 1, signature: "" });
        signatures_[1] = IPayerReportManager.PayerReportSignature({ nodeId: 0, signature: "" });

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1), abi.encode(false));

        vm.expectRevert(IPayerReportManager.UnorderedNodeIds.selector);

        _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0),
            signatures_: signatures_
        });
    }

    function test_internal_verifySignatures_insufficientSignatures() external {
        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.InsufficientSignatures.selector, 0, 1));

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("canonicalNodesCount()"), abi.encode(1));

        _manager.__verifySignatures({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0),
            signatures_: new IPayerReportManager.PayerReportSignature[](0)
        });
    }

    /* ============ _verifySignature ============ */

    function test_internal_verifySignature_notCanonicalNode() external {
        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(false)
        );

        assertFalse(_manager.__verifySignature(0, 1, ""));
    }

    function test_internal_verifySignature_invalidSignature() external {
        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        assertFalse(_manager.__verifySignature(0, 1, ""));
    }

    function test_internal_verifySignature_notNodeOwner() external {
        bytes memory signature_ = _getPayerReportSignature({
            originatorNodeId_: 0,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: new uint32[](0),
            privateKey_: _signer1Pk
        });

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(0));

        assertFalse(_manager.__verifySignature(0, 1, signature_));
    }

    function test_internal_verifySignature() external {
        bytes memory signature_ = _getSignature(0, _signer1Pk);

        Utils.expectAndMockCall(
            _nodeRegistry,
            abi.encodeWithSignature("getIsCanonicalNode(uint32)", 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("getSigner(uint32)", 1), abi.encode(_signer1));

        assertTrue(_manager.__verifySignature(0, 1, signature_));
    }

    /* ============ getPayerReportDigest ============ */

    function test_getPayerReportDigest() external view {
        assertEq(
            _manager.getPayerReportDigest({
                originatorNodeId_: 1,
                startSequenceId_: 2,
                endSequenceId_: 3,
                endMinuteSinceEpoch_: 4,
                payersMerkleRoot_: bytes32(uint256(5)),
                nodeIds_: new uint32[](6)
            }),
            0xe95b9352b7afb9da83952cce75aba1d466ed7daeafc009c1964b85b8fe08bc09
        );

        assertEq(
            _manager.getPayerReportDigest({
                originatorNodeId_: 10,
                startSequenceId_: 20,
                endSequenceId_: 30,
                endMinuteSinceEpoch_: 40,
                payersMerkleRoot_: bytes32(uint256(50)),
                nodeIds_: new uint32[](60)
            }),
            0x1dcb9deef4cebf9e13169296e27dee6166ed09af01b62f5c65dff9b3a9afb82d
        );
    }

    function test_getPayerReportDigest_sample1() external view {
        bytes32 payersMerkleRoot_ = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        uint32[] memory nodeIds_ = new uint32[](5);

        nodeIds_[0] = 100;
        nodeIds_[1] = 200;
        nodeIds_[2] = 300;
        nodeIds_[3] = 400;
        nodeIds_[4] = 500;

        assertEq(
            _manager.getPayerReportDigest({
                originatorNodeId_: 1,
                startSequenceId_: 2,
                endSequenceId_: 3,
                endMinuteSinceEpoch_: 4,
                payersMerkleRoot_: payersMerkleRoot_,
                nodeIds_: nodeIds_
            }),
            0x79f316f2836745161f3020e431db382ce57aab339df1429de068a62bf940295b
        );
    }

    /* ============ getPayerReports ============ */

    function test_getPayerReports_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.ArrayLengthMismatch.selector));
        _manager.getPayerReports(new uint32[](1), new uint256[](2));
    }

    function test_getPayerReports() external {
        uint32[] memory nodeIds_ = new uint32[](8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            protocolFeeRate_: 6,
            payersMerkleRoot_: bytes32(uint256(7)),
            nodeIds_: nodeIds_
        });

        _manager.__pushPayerReport({
            originatorNodeId_: 10,
            startSequenceId_: 20,
            endSequenceId_: 30,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 40,
            offset_: 50,
            isSettled_: true,
            protocolFeeRate_: 60,
            payersMerkleRoot_: bytes32(uint256(70)),
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
        assertEq(payerReports_[0].protocolFeeRate, 6);
        assertEq(payerReports_[0].payersMerkleRoot, bytes32(uint256(7)));
        assertEq(payerReports_[0].nodeIds.length, 8);

        assertEq(payerReports_[1].startSequenceId, 20);
        assertEq(payerReports_[1].endSequenceId, 30);
        assertEq(payerReports_[1].feesSettled, 40);
        assertEq(payerReports_[1].offset, 50);
        assertTrue(payerReports_[1].isSettled);
        assertEq(payerReports_[1].protocolFeeRate, 60);
        assertEq(payerReports_[1].payersMerkleRoot, bytes32(uint256(70)));
        assertEq(payerReports_[1].nodeIds.length, 8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReports_[0].nodeIds[index_], 10 + index_);
        }

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReports_[1].nodeIds[index_], 10 + index_);
        }
    }
    function test_getPayerReports_noReportsForOriginator() external {
        uint32[] memory nodeIds_ = new uint32[](8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        // Only originator 1 has a report; originator 2 has none -> should revert on i=1.
        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_
        });

        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 1;
        originatorNodeIds_[1] = 2;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.NoReportsForOriginator.selector, uint32(2)));
        _manager.getPayerReports(originatorNodeIds_, payerReportIndices_);
    }

    function test_getPayerReports_indexOutOfBounds() external {
        uint32[] memory nodeIds_ = new uint32[](8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        // Both originators have exactly one report.
        for (uint32 oid = 1; oid <= 2; oid++) {
            _manager.__pushPayerReport({
                originatorNodeId_: oid,
                startSequenceId_: 0,
                endSequenceId_: 0,
                endMinuteSinceEpoch_: 0,
                feesSettled_: 0,
                offset_: 0,
                isSettled_: false,
                protocolFeeRate_: 0,
                payersMerkleRoot_: 0,
                nodeIds_: nodeIds_
            });
        }

        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 1;
        originatorNodeIds_[1] = 2;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 1; // OOB for originator 1
        payerReportIndices_[1] = 0; // OK for originator 2

        vm.expectRevert(IPayerReportManager.PayerReportIndexOutOfBounds.selector);
        _manager.getPayerReports(originatorNodeIds_, payerReportIndices_);
    }

    /* ============ getPayerReport ============ */

    function test_getPayerReport() external {
        uint32[] memory nodeIds_ = new uint32[](8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 2,
            endSequenceId_: 3,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 4,
            offset_: 5,
            isSettled_: true,
            protocolFeeRate_: 6,
            payersMerkleRoot_: bytes32(uint256(7)),
            nodeIds_: nodeIds_
        });

        IPayerReportManager.PayerReport memory payerReport_ = _manager.getPayerReport(1, 0);

        assertEq(payerReport_.startSequenceId, 2);
        assertEq(payerReport_.endSequenceId, 3);
        assertEq(payerReport_.feesSettled, 4);
        assertEq(payerReport_.offset, 5);
        assertTrue(payerReport_.isSettled);
        assertEq(payerReport_.protocolFeeRate, 6);
        assertEq(payerReport_.payersMerkleRoot, bytes32(uint256(7)));
        assertEq(payerReport_.nodeIds.length, 8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            assertEq(payerReport_.nodeIds[index_], 10 + index_);
        }
    }

    function test_getPayerReport_noReportsForOriginator() external {
        // originator 123 has no reports at all
        vm.expectRevert(abi.encodeWithSelector(IPayerReportManager.NoReportsForOriginator.selector, uint32(123)));
        _manager.getPayerReport(123, 0);
    }

    function test_getPayerReport_indexOutOfBounds() external {
        uint32[] memory nodeIds_ = new uint32[](8);

        for (uint32 index_; index_ < nodeIds_.length; ++index_) {
            nodeIds_[index_] = 10 + index_;
        }

        // push exactly one report for originator 1 (index 0 valid, index 1 OOB)
        _manager.__pushPayerReport({
            originatorNodeId_: 1,
            startSequenceId_: 0,
            endSequenceId_: 0,
            endMinuteSinceEpoch_: 0,
            feesSettled_: 0,
            offset_: 0,
            isSettled_: false,
            protocolFeeRate_: 0,
            payersMerkleRoot_: 0,
            nodeIds_: nodeIds_
        });

        vm.expectRevert(IPayerReportManager.PayerReportIndexOutOfBounds.selector);
        _manager.getPayerReport(1, 1);
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
                "PayerReport(uint32 originatorNodeId,uint64 startSequenceId,uint64 endSequenceId,uint32 endMinuteSinceEpoch,bytes32 payersMerkleRoot,uint32[] nodeIds)"
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
        assertEq(salt_, 0);
        assertEq(extensions_.length, 0);
    }

    /* ============ helper functions ============ */

    function _getPayerReportSignature(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
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
                    endMinuteSinceEpoch_,
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
