// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { DistributionManagerHarness } from "../utils/Harnesses.sol";

import { MockMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract DistributionManagerTests is Test {
    string internal constant _MIGRATOR_KEY = "xmtp.distributionManager.migrator";
    string internal constant _PAUSED_KEY = "xmtp.distributionManager.paused";
    string internal constant _PROTOCOL_FEES_RECIPIENT_KEY = "xmtp.distributionManager.protocolFeesRecipient";

    DistributionManagerHarness internal _manager;

    address internal _implementation;

    address internal _nodeRegistry = makeAddr("nodeRegistry");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _payerRegistry = makeAddr("payerRegistry");
    address internal _payerReportManager = makeAddr("payerReportManager");
    address internal _feeToken = makeAddr("feeToken");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");

    function setUp() external {
        _implementation = address(
            new DistributionManagerHarness(
                _parameterRegistry,
                _nodeRegistry,
                _payerReportManager,
                _payerRegistry,
                _feeToken
            )
        );

        _manager = DistributionManagerHarness(address(new Proxy(_implementation)));

        _manager.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IDistributionManager.ZeroParameterRegistry.selector);
        new DistributionManagerHarness(address(0), address(0), address(0), address(0), address(0));
    }

    function test_constructor_zeroNodeRegistry() external {
        vm.expectRevert(IDistributionManager.ZeroNodeRegistry.selector);
        new DistributionManagerHarness(_parameterRegistry, address(0), address(0), address(0), address(0));
    }

    function test_constructor_zeroPayerReportManager() external {
        vm.expectRevert(IDistributionManager.ZeroPayerReportManager.selector);
        new DistributionManagerHarness(_parameterRegistry, _nodeRegistry, address(0), address(0), address(0));
    }

    function test_constructor_zeroPayerRegistry() external {
        vm.expectRevert(IDistributionManager.ZeroPayerRegistry.selector);
        new DistributionManagerHarness(_parameterRegistry, _nodeRegistry, _payerReportManager, address(0), address(0));
    }

    function test_constructor_zeroFeeToken() external {
        vm.expectRevert(IDistributionManager.ZeroFeeToken.selector);
        new DistributionManagerHarness(
            _parameterRegistry,
            _nodeRegistry,
            _payerReportManager,
            _payerRegistry,
            address(0)
        );
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_manager)), _implementation);
        assertEq(_manager.implementation(), _implementation);
        assertEq(_manager.parameterRegistry(), _parameterRegistry);
        assertEq(_manager.nodeRegistry(), _nodeRegistry);
        assertEq(_manager.payerReportManager(), _payerReportManager);
        assertEq(_manager.feeToken(), _feeToken);
        assertEq(_manager.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_manager.pausedParameterKey(), _PAUSED_KEY);
        assertEq(_manager.protocolFeesRecipientParameterKey(), _PROTOCOL_FEES_RECIPIENT_KEY);
        assertFalse(_manager.paused());
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_manager.version(), "1.0.1");
    }

    /* ============ contractName ============ */

    function test_contractName() external view {
        assertEq(_manager.contractName(), "DistributionManager");
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _manager.initialize();
    }

    /* ============ claimProtocolFees ============ */

    function test_claimProtocolFees_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.claimProtocolFees(new uint32[](0), new uint256[](0));
    }

    function test_claimProtocolFees_arrayLengthMismatch() external {
        vm.expectRevert(IDistributionManager.ArrayLengthMismatch.selector);
        _manager.claimProtocolFees(new uint32[](0), new uint256[](1));
    }

    function test_claimProtocolFees_alreadyClaimed() external {
        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: new uint32[](0)
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: new uint32[](0)
        });

        _manager.__setAreProtocolFeesClaimed(3, 0, true); // Protocol fee already claimed node 3's 0th payer report.

        vm.mockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.AlreadyClaimed.selector, 3, 0));

        _manager.claimProtocolFees(originatorNodeIds_, payerReportIndices_);
    }

    function test_claimProtocolFees_payerReportNotSettled() external {
        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: new uint32[](0)
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: false, // Second payer report is not settled.
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: new uint32[](0)
        });

        vm.mockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.PayerReportNotSettled.selector, 3, 0));

        _manager.claimProtocolFees(originatorNodeIds_, payerReportIndices_);
    }

    function test_claimProtocolFees() external {
        _manager.__setOwedProtocolFees(300);

        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 1;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 100,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 1_000, // 10%
            payersMerkleRoot: 0,
            nodeIds: new uint32[](3)
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 200,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 750, // 7.5%
            payersMerkleRoot: 0,
            nodeIds: new uint32[](3)
        });

        Utils.expectAndMockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesClaim(2, 0, 10); // 10% of 100.
        emit IDistributionManager.ProtocolFeesClaim(3, 1, 17); // 7.5% of 200, plus 2 due to node rounding.

        uint96 claimed_ = _manager.claimProtocolFees(originatorNodeIds_, payerReportIndices_);

        assertEq(claimed_, 10 + 17);
        assertEq(_manager.owedProtocolFees(), 300 + claimed_);
        assertEq(_manager.areProtocolFeesClaimed(2, 0), true);
        assertEq(_manager.areProtocolFeesClaimed(3, 1), true);
    }

    /* ============ claim ============ */

    function test_claim_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.claim(0, new uint32[](0), new uint256[](0));
    }

    function test_claim_notNodeOwner() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.NotNodeOwner.selector);

        vm.prank(_bob);
        _manager.claim(1, new uint32[](0), new uint256[](0));
    }

    function test_claim_arrayLengthMismatch() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.ArrayLengthMismatch.selector);

        vm.prank(_alice);
        _manager.claim(1, new uint32[](0), new uint256[](1));
    }

    function test_claim_alreadyClaimed() external {
        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        _manager.__setAreFeesClaimed(1, 3, 0, true); // Node 1 has already claimed node 3's 0th payer report.

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.mockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.AlreadyClaimed.selector, 3, 0));

        vm.prank(_alice);
        _manager.claim(1, originatorNodeIds_, payerReportIndices_);
    }

    function test_claim_payerReportNotSettled() external {
        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: false, // Second payer report is not settled.
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.mockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.PayerReportNotSettled.selector, 3, 0));

        vm.prank(_alice);
        _manager.claim(1, originatorNodeIds_, payerReportIndices_);
    }

    function test_claim_notInPayerReport() external {
        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 0;

        uint32[] memory nodeIdsContainingNode1_ = new uint32[](3);
        nodeIdsContainingNode1_[0] = 1;
        nodeIdsContainingNode1_[1] = 2;
        nodeIdsContainingNode1_[2] = 3;

        uint32[] memory nodeIdsNotContainingNode1_ = new uint32[](2);
        nodeIdsNotContainingNode1_[0] = 2;
        nodeIdsNotContainingNode1_[1] = 3;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIdsContainingNode1_
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 0,
            payersMerkleRoot: 0,
            nodeIds: nodeIdsNotContainingNode1_ // Node 1 is not in the second payer report.
        });

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.mockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.NotInPayerReport.selector, 3, 0));

        vm.prank(_alice);
        _manager.claim(1, originatorNodeIds_, payerReportIndices_);
    }

    function test_claim() external {
        _manager.__setOwedFees(1, 300);
        _manager.__setTotalOwedFees(500);

        uint32[] memory originatorNodeIds_ = new uint32[](2);
        originatorNodeIds_[0] = 2;
        originatorNodeIds_[1] = 3;

        uint256[] memory payerReportIndices_ = new uint256[](2);
        payerReportIndices_[0] = 0;
        payerReportIndices_[1] = 1;

        uint32[] memory nodeIds_ = new uint32[](3);
        nodeIds_[0] = 1;
        nodeIds_[1] = 2;
        nodeIds_[2] = 3;

        IPayerReportManager.PayerReport[] memory payerReports_ = new IPayerReportManager.PayerReport[](2);

        payerReports_[0] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 100,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 1_000, // 10%
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManager.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            endMinuteSinceEpoch: 0,
            feesSettled: 200,
            offset: 0,
            isSettled: true,
            protocolFeeRate: 750, // 7.5%
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _payerReportManager,
            abi.encodeWithSignature("getPayerReports(uint32[],uint256[])", originatorNodeIds_, payerReportIndices_),
            abi.encode(payerReports_)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Claim(1, 2, 0, uint96(90) / 3); // 90 after 10% protocol fees.
        emit IDistributionManager.Claim(1, 3, 1, uint96(185) / 3); // 185 after 7.5% protocol fees.

        vm.prank(_alice);
        uint96 claimed_ = _manager.claim(1, originatorNodeIds_, payerReportIndices_);

        assertEq(claimed_, (uint96(90) / 3) + (uint96(185) / 3));
        assertEq(_manager.getOwedFees(1), 300 + claimed_);
        assertEq(_manager.totalOwedFees(), 500 + claimed_);
        assertEq(_manager.areFeesClaimed(1, 2, 0), true);
        assertEq(_manager.areFeesClaimed(1, 3, 1), true);
    }

    // TODO: Maybe a fuzz test for claim.

    /* ============ _prepareProtocolFeesWithdrawal ============ */

    function test_internal_prepareProtocolFeesWithdrawal_zeroRecipient() external {
        vm.expectRevert(IDistributionManager.ZeroRecipient.selector);
        _manager.__prepareProtocolFeesWithdrawal(address(0));
    }

    function test_internal_prepareProtocolFeesWithdrawal_noFeesOwed() external {
        vm.expectRevert(IDistributionManager.NoFeesOwed.selector);
        _manager.__prepareProtocolFeesWithdrawal(address(1));
    }

    function test_internal_prepareProtocolFeesWithdrawal_zeroAvailableBalance() external {
        _manager.__setOwedProtocolFees(1);

        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(0));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);

        _manager.__prepareProtocolFeesWithdrawal(address(1));
    }

    function test_internal_prepareProtocolFeesWithdrawal_noPayerRegistryExcess() external {
        _manager.__setOwedProtocolFees(1);

        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(1));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        uint96 withdrawn_ = _manager.__prepareProtocolFeesWithdrawal(address(1));

        assertEq(withdrawn_, 1);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    function test_internal_prepareProtocolFeesWithdrawal_withPayerRegistryExcess() external {
        _manager.__setOwedProtocolFees(2);

        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(1));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(1));

        uint96 withdrawn_ = _manager.__prepareProtocolFeesWithdrawal(address(1));

        assertEq(withdrawn_, 2);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    /* ============ withdrawProtocolFees ============ */

    function test_withdrawProtocolFees_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.withdrawProtocolFees();
    }

    function test_withdrawProtocolFees_zeroProtocolFeeRecipient() external {
        _manager.__setProtocolFeesRecipient(address(0));

        vm.expectRevert(IDistributionManager.ZeroProtocolFeeRecipient.selector);
        _manager.withdrawProtocolFees();
    }

    function test_withdrawProtocolFees_partial_noPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", address(1), 5),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(5);

        uint96 withdrawn_ = _manager.withdrawProtocolFees();

        assertEq(withdrawn_, 5);
        assertEq(_manager.owedProtocolFees(), 5);
    }

    function test_withdrawProtocolFees_full_noPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", address(1), 10),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(10);

        uint96 withdrawn_ = _manager.withdrawProtocolFees();

        assertEq(withdrawn_, 10);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    function test_withdrawProtocolFees_partial_withPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(3));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", address(1), 8),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(8);

        uint96 withdrawn_ = _manager.withdrawProtocolFees();

        assertEq(withdrawn_, 8);
        assertEq(_manager.owedProtocolFees(), 2);
    }

    function test_withdrawProtocolFees_full_withPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(15);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(5));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", address(1), 15),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(15);

        uint96 withdrawn_ = _manager.withdrawProtocolFees();

        assertEq(withdrawn_, 15);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    function testFuzz_withdrawProtocolFees(
        uint96 owedProtocolFees_,
        uint96 availableBalance_,
        uint96 payerRegistryExcess_
    ) external {
        _manager.__setProtocolFeesRecipient(address(1));

        owedProtocolFees_ = uint96(_bound(owedProtocolFees_, 0, type(uint96).max));
        availableBalance_ = uint96(_bound(availableBalance_, 0, type(uint96).max));
        payerRegistryExcess_ = uint96(_bound(payerRegistryExcess_, 0, type(uint96).max - availableBalance_));

        _manager.__setOwedProtocolFees(owedProtocolFees_);

        if (owedProtocolFees_ > 0) {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("balanceOf(address)", address(_manager)),
                abi.encode(uint256(availableBalance_))
            );
        }

        if (owedProtocolFees_ > 0 && availableBalance_ < owedProtocolFees_) {
            Utils.expectAndMockCall(
                _payerRegistry,
                abi.encodeWithSignature("sendExcessToFeeDistributor()"),
                abi.encode(uint256(payerRegistryExcess_))
            );
        }

        uint96 expectedWithdrawal_ = availableBalance_ + payerRegistryExcess_ > owedProtocolFees_
            ? owedProtocolFees_
            : availableBalance_ + payerRegistryExcess_;

        if (owedProtocolFees_ == 0) {
            vm.expectRevert(IDistributionManager.NoFeesOwed.selector);
        } else if (availableBalance_ + payerRegistryExcess_ == 0) {
            vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);
        } else {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("transfer(address,uint256)", address(1), expectedWithdrawal_),
                abi.encode(true)
            );

            vm.expectEmit(address(_manager));
            emit IDistributionManager.ProtocolFeesWithdrawal(expectedWithdrawal_);
        }

        uint96 withdrawn_ = _manager.withdrawProtocolFees();

        if (owedProtocolFees_ == 0 || availableBalance_ + payerRegistryExcess_ == 0) return;

        assertEq(withdrawn_, expectedWithdrawal_);
        assertEq(_manager.owedProtocolFees(), owedProtocolFees_ - expectedWithdrawal_);
    }

    /* ============ withdrawProtocolFeesIntoUnderlying ============ */

    function test_withdrawProtocolFeesIntoUnderlying_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.withdrawProtocolFeesIntoUnderlying();
    }

    function test_withdrawProtocolFeesIntoUnderlying_zeroProtocolFeeRecipient() external {
        _manager.__setProtocolFeesRecipient(address(0));

        vm.expectRevert(IDistributionManager.ZeroProtocolFeeRecipient.selector);
        _manager.withdrawProtocolFeesIntoUnderlying();
    }

    function test_withdrawProtocolFeesIntoUnderlying_partial_noPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", address(1), 5),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(5);

        uint96 withdrawn_ = _manager.withdrawProtocolFeesIntoUnderlying();

        assertEq(withdrawn_, 5);
        assertEq(_manager.owedProtocolFees(), 5);
    }

    function test_withdrawProtocolFeesIntoUnderlying_full_noPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", address(1), 10),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(10);

        uint96 withdrawn_ = _manager.withdrawProtocolFeesIntoUnderlying();

        assertEq(withdrawn_, 10);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    function test_withdrawProtocolFeesIntoUnderlying_partial_withPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(10);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(3));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", address(1), 8),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(8);

        uint96 withdrawn_ = _manager.withdrawProtocolFeesIntoUnderlying();

        assertEq(withdrawn_, 8);
        assertEq(_manager.owedProtocolFees(), 2);
    }

    function test_withdrawProtocolFeesIntoUnderlying_full_withPayerRegistryExcess() external {
        _manager.__setProtocolFeesRecipient(address(1));
        _manager.__setOwedProtocolFees(15);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(5));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", address(1), 15),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesWithdrawal(15);

        uint96 withdrawn_ = _manager.withdrawProtocolFeesIntoUnderlying();

        assertEq(withdrawn_, 15);
        assertEq(_manager.owedProtocolFees(), 0);
    }

    function testFuzz_withdrawProtocolFeesIntoUnderlying(
        uint96 owedProtocolFees_,
        uint96 availableBalance_,
        uint96 payerRegistryExcess_
    ) external {
        _manager.__setProtocolFeesRecipient(address(1));

        owedProtocolFees_ = uint96(_bound(owedProtocolFees_, 0, type(uint96).max));
        availableBalance_ = uint96(_bound(availableBalance_, 0, type(uint96).max));
        payerRegistryExcess_ = uint96(_bound(payerRegistryExcess_, 0, type(uint96).max - availableBalance_));

        _manager.__setOwedProtocolFees(owedProtocolFees_);

        if (owedProtocolFees_ > 0) {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("balanceOf(address)", address(_manager)),
                abi.encode(uint256(availableBalance_))
            );
        }

        if (owedProtocolFees_ > 0 && availableBalance_ < owedProtocolFees_) {
            Utils.expectAndMockCall(
                _payerRegistry,
                abi.encodeWithSignature("sendExcessToFeeDistributor()"),
                abi.encode(uint256(payerRegistryExcess_))
            );
        }

        uint96 expectedWithdrawal_ = availableBalance_ + payerRegistryExcess_ > owedProtocolFees_
            ? owedProtocolFees_
            : availableBalance_ + payerRegistryExcess_;

        if (owedProtocolFees_ == 0) {
            vm.expectRevert(IDistributionManager.NoFeesOwed.selector);
        } else if (availableBalance_ + payerRegistryExcess_ == 0) {
            vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);
        } else {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("withdrawTo(address,uint256)", address(1), expectedWithdrawal_),
                abi.encode(true)
            );

            vm.expectEmit(address(_manager));
            emit IDistributionManager.ProtocolFeesWithdrawal(expectedWithdrawal_);
        }

        uint96 withdrawn_ = _manager.withdrawProtocolFeesIntoUnderlying();

        if (owedProtocolFees_ == 0 || availableBalance_ + payerRegistryExcess_ == 0) return;

        assertEq(withdrawn_, expectedWithdrawal_);
        assertEq(_manager.owedProtocolFees(), owedProtocolFees_ - expectedWithdrawal_);
    }

    /* ============ _prepareWithdrawal ============ */

    function test_internal_prepareWithdrawal_zeroRecipient() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.ZeroRecipient.selector);

        _manager.__prepareWithdrawal(1, address(0));
    }

    function test_internal_prepareWithdrawal_notNodeOwner() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.NotNodeOwner.selector);

        vm.prank(_bob);
        _manager.__prepareWithdrawal(1, _bob);
    }

    function test_internal_prepareWithdrawal_noFeesOwed() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.NoFeesOwed.selector);

        vm.prank(_alice);
        _manager.__prepareWithdrawal(1, _alice);
    }

    function test_internal_prepareWithdrawal_zeroAvailableBalance() external {
        _manager.__setOwedFees(1, 1);

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(0));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);

        vm.prank(_alice);
        _manager.__prepareWithdrawal(1, _alice);
    }

    function test_internal_prepareWithdrawal_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 1);
        _manager.__setTotalOwedFees(2);

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(1));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.__prepareWithdrawal(1, _alice);

        assertEq(withdrawn_, 1);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 1);
    }

    function test_internal_prepareWithdrawal_withPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 2);
        _manager.__setTotalOwedFees(3);

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(1));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(1));

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.__prepareWithdrawal(1, _alice);

        assertEq(withdrawn_, 2);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 1);
    }

    /* ============ withdraw ============ */

    function test_withdraw_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.withdraw(0, address(0));
    }

    function test_withdraw_partial_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 5),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 5);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdraw(1, _alice);

        assertEq(withdrawn_, 5);
        assertEq(_manager.getOwedFees(1), 5);
        assertEq(_manager.totalOwedFees(), 15);
    }

    function test_withdraw_full_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 10),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 10);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdraw(1, _alice);

        assertEq(withdrawn_, 10);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 10);
    }

    function test_withdraw_partial_withPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(3));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 8),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 8);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdraw(1, _alice);

        assertEq(withdrawn_, 8);
        assertEq(_manager.getOwedFees(1), 2);
        assertEq(_manager.totalOwedFees(), 12);
    }

    function test_withdraw_full_withPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 15);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(5));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 15),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 15);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdraw(1, _alice);

        assertEq(withdrawn_, 15);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 5);
    }

    function testFuzz_withdraw(
        uint96 totalOwedFees_,
        uint96 owedFees_,
        uint96 availableBalance_,
        uint96 payerRegistryExcess_
    ) external {
        owedFees_ = uint96(_bound(owedFees_, 0, type(uint96).max));
        totalOwedFees_ = uint96(_bound(totalOwedFees_, owedFees_, type(uint96).max));
        availableBalance_ = uint96(_bound(availableBalance_, 0, type(uint96).max));
        payerRegistryExcess_ = uint96(_bound(payerRegistryExcess_, 0, type(uint96).max - availableBalance_));

        _manager.__setOwedFees(1, owedFees_);
        _manager.__setTotalOwedFees(totalOwedFees_);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        if (owedFees_ > 0) {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("balanceOf(address)", address(_manager)),
                abi.encode(uint256(availableBalance_))
            );
        }

        if (owedFees_ > 0 && availableBalance_ < owedFees_) {
            Utils.expectAndMockCall(
                _payerRegistry,
                abi.encodeWithSignature("sendExcessToFeeDistributor()"),
                abi.encode(uint256(payerRegistryExcess_))
            );
        }

        uint96 expectedWithdrawal_ = availableBalance_ + payerRegistryExcess_ > owedFees_
            ? owedFees_
            : availableBalance_ + payerRegistryExcess_;

        if (owedFees_ == 0) {
            vm.expectRevert(IDistributionManager.NoFeesOwed.selector);
        } else if (availableBalance_ + payerRegistryExcess_ == 0) {
            vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);
        } else {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("transfer(address,uint256)", _alice, expectedWithdrawal_),
                abi.encode(true)
            );

            vm.expectEmit(address(_manager));
            emit IDistributionManager.Withdrawal(1, expectedWithdrawal_);
        }

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdraw(1, _alice);

        if (owedFees_ == 0 || availableBalance_ + payerRegistryExcess_ == 0) return;

        assertEq(withdrawn_, expectedWithdrawal_);
        assertEq(_manager.getOwedFees(1), owedFees_ - expectedWithdrawal_);
        assertEq(_manager.totalOwedFees(), totalOwedFees_ - expectedWithdrawal_);
    }

    /* ============ withdrawIntoUnderlying ============ */

    function test_withdrawIntoUnderlying_paused() external {
        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.Paused.selector);
        _manager.withdrawIntoUnderlying(0, address(0));
    }

    function test_withdrawIntoUnderlying_partial_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 5),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 5);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdrawIntoUnderlying(1, _alice);

        assertEq(withdrawn_, 5);
        assertEq(_manager.getOwedFees(1), 5);
        assertEq(_manager.totalOwedFees(), 15);
    }

    function test_withdrawIntoUnderlying_full_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 10),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 10);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdrawIntoUnderlying(1, _alice);

        assertEq(withdrawn_, 10);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 10);
    }

    function test_withdrawIntoUnderlying_partial_withPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(3));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 8),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 8);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdrawIntoUnderlying(1, _alice);

        assertEq(withdrawn_, 8);
        assertEq(_manager.getOwedFees(1), 2);
        assertEq(_manager.totalOwedFees(), 12);
    }

    function test_withdrawIntoUnderlying_full_withPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 15);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(5));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 15),
            abi.encode(true)
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.Withdrawal(1, 15);

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdrawIntoUnderlying(1, _alice);

        assertEq(withdrawn_, 15);
        assertEq(_manager.getOwedFees(1), 0);
        assertEq(_manager.totalOwedFees(), 5);
    }

    function testFuzz_withdrawIntoUnderlying(
        uint96 totalOwedFees_,
        uint96 owedFees_,
        uint96 availableBalance_,
        uint96 payerRegistryExcess_
    ) external {
        owedFees_ = uint96(_bound(owedFees_, 0, type(uint96).max));
        totalOwedFees_ = uint96(_bound(totalOwedFees_, owedFees_, type(uint96).max));
        availableBalance_ = uint96(_bound(availableBalance_, 0, type(uint96).max));
        payerRegistryExcess_ = uint96(_bound(payerRegistryExcess_, 0, type(uint96).max - availableBalance_));

        _manager.__setOwedFees(1, owedFees_);
        _manager.__setTotalOwedFees(totalOwedFees_);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        if (owedFees_ > 0) {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("balanceOf(address)", address(_manager)),
                abi.encode(uint256(availableBalance_))
            );
        }

        if (owedFees_ > 0 && availableBalance_ < owedFees_) {
            Utils.expectAndMockCall(
                _payerRegistry,
                abi.encodeWithSignature("sendExcessToFeeDistributor()"),
                abi.encode(uint256(payerRegistryExcess_))
            );
        }

        uint96 expectedWithdrawal_ = availableBalance_ + payerRegistryExcess_ > owedFees_
            ? owedFees_
            : availableBalance_ + payerRegistryExcess_;

        if (owedFees_ == 0) {
            vm.expectRevert(IDistributionManager.NoFeesOwed.selector);
        } else if (availableBalance_ + payerRegistryExcess_ == 0) {
            vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);
        } else {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, expectedWithdrawal_),
                abi.encode(true)
            );

            vm.expectEmit(address(_manager));
            emit IDistributionManager.Withdrawal(1, expectedWithdrawal_);
        }

        vm.prank(_alice);
        uint96 withdrawn_ = _manager.withdrawIntoUnderlying(1, _alice);

        if (owedFees_ == 0 || availableBalance_ + payerRegistryExcess_ == 0) return;

        assertEq(withdrawn_, expectedWithdrawal_);
        assertEq(_manager.getOwedFees(1), owedFees_ - expectedWithdrawal_);
        assertEq(_manager.totalOwedFees(), totalOwedFees_ - expectedWithdrawal_);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _manager.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(IDistributionManager.NoChange.selector);

        _manager.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _manager.__setPauseStatus(true);

        vm.expectRevert(IDistributionManager.NoChange.selector);

        _manager.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_manager));
        emit IDistributionManager.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _manager.updatePauseStatus();

        assertTrue(_manager.paused());

        vm.expectEmit(address(_manager));
        emit IDistributionManager.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        _manager.updatePauseStatus();

        assertFalse(_manager.paused());
    }

    /* ============ updateProtocolFeesRecipient ============ */

    function test_updateProtocolFeesRecipient_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PROTOCOL_FEES_RECIPIENT_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _manager.updateProtocolFeesRecipient();
    }

    function test_updateProtocolFeesRecipient_noChange() external {
        _manager.__setProtocolFeesRecipient(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PROTOCOL_FEES_RECIPIENT_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(IDistributionManager.NoChange.selector);

        _manager.updateProtocolFeesRecipient();
    }

    function test_updateProtocolFeesRecipient() external {
        _manager.__setProtocolFeesRecipient(address(1));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _PROTOCOL_FEES_RECIPIENT_KEY,
            bytes32(uint256(uint160(address(2))))
        );

        vm.expectEmit(address(_manager));
        emit IDistributionManager.ProtocolFeesRecipientUpdated(address(2));

        _manager.updateProtocolFeesRecipient();

        assertEq(_manager.protocolFeesRecipient(), address(2));
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
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _manager.migrate();
    }

    function test_migrate() external {
        _manager.__setOwedFees(1, 2);
        _manager.__setAreFeesClaimed(1, 2, 0, true);

        address newImplementation_ = address(
            new DistributionManagerHarness(
                _parameterRegistry,
                _nodeRegistry,
                _payerReportManager,
                _payerRegistry,
                _feeToken
            )
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
        assertEq(_manager.nodeRegistry(), _nodeRegistry);
        assertEq(_manager.payerReportManager(), _payerReportManager);
        assertEq(_manager.payerRegistry(), _payerRegistry);
        assertEq(_manager.feeToken(), _feeToken);

        assertEq(_manager.getOwedFees(1), 2);
        assertEq(_manager.areFeesClaimed(1, 2, 0), true);
    }

    /* ============ owedProtocolFees ============ */

    function test_owedProtocolFees() external {
        _manager.__setOwedProtocolFees(1);

        assertEq(_manager.owedProtocolFees(), 1);

        _manager.__setOwedProtocolFees(100);

        assertEq(_manager.owedProtocolFees(), 100);
    }

    /* ============ totalOwedFees ============ */

    function test_totalOwedFees() external {
        _manager.__setTotalOwedFees(1);

        assertEq(_manager.totalOwedFees(), 1);

        _manager.__setTotalOwedFees(100);

        assertEq(_manager.totalOwedFees(), 100);
    }

    /* ============ getOwedFees ============ */

    function test_getOwedFees() external {
        _manager.__setOwedFees(1, 2);
        _manager.__setOwedFees(3, 4);

        assertEq(_manager.getOwedFees(1), 2);
        assertEq(_manager.getOwedFees(3), 4);
    }

    /* ============ areProtocolFeesClaimed ============ */

    function test_areProtocolFeesClaimed() external {
        _manager.__setAreProtocolFeesClaimed(2, 0, true);
        _manager.__setAreProtocolFeesClaimed(2, 1, false);
        _manager.__setAreProtocolFeesClaimed(3, 0, true);

        assertEq(_manager.areProtocolFeesClaimed(2, 0), true);
        assertEq(_manager.areProtocolFeesClaimed(2, 1), false);
        assertEq(_manager.areProtocolFeesClaimed(3, 0), true);
    }

    /* ============ areFeesClaimed ============ */

    function test_areFeesClaimed() external {
        _manager.__setAreFeesClaimed(1, 2, 0, true);
        _manager.__setAreFeesClaimed(1, 2, 1, false);
        _manager.__setAreFeesClaimed(1, 3, 0, true);

        _manager.__setAreFeesClaimed(2, 2, 0, false);
        _manager.__setAreFeesClaimed(2, 2, 1, true);
        _manager.__setAreFeesClaimed(2, 3, 0, false);

        assertEq(_manager.areFeesClaimed(1, 2, 0), true);
        assertEq(_manager.areFeesClaimed(1, 2, 1), false);
        assertEq(_manager.areFeesClaimed(1, 3, 0), true);

        assertEq(_manager.areFeesClaimed(2, 2, 0), false);
        assertEq(_manager.areFeesClaimed(2, 2, 1), true);
        assertEq(_manager.areFeesClaimed(2, 3, 0), false);
    }
}
