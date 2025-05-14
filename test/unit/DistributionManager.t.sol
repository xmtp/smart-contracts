// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IPayerReportManagerLike } from "../../src/settlement-chain/interfaces/External.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { DistributionManagerHarness } from "../utils/Harnesses.sol";

import { MockMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract DistributionManagerTests is Test {
    bytes internal constant _MIGRATOR_KEY = "xmtp.distributionManager.migrator";

    DistributionManagerHarness internal _manager;

    address internal _implementation;

    address internal _nodeRegistry = makeAddr("nodeRegistry");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _payerRegistry = makeAddr("payerRegistry");
    address internal _payerReportManager = makeAddr("payerReportManager");
    address internal _token = makeAddr("token");

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
                _token
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

    function test_constructor_zeroToken() external {
        vm.expectRevert(IDistributionManager.ZeroToken.selector);
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
        assertEq(_manager.token(), _token);
        assertEq(_manager.migratorParameterKey(), _MIGRATOR_KEY);
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _manager.initialize();
    }

    /* ============ claim ============ */

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

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = new IPayerReportManagerLike.PayerReport[](2);

        payerReports_[0] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        _manager.__setHasClaimed(1, 3, 0, true); // Node 1 has already claimed node 3's 0th payer report.

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

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = new IPayerReportManagerLike.PayerReport[](2);

        payerReports_[0] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: false, // Second payer report is not settled.
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

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = new IPayerReportManagerLike.PayerReport[](2);

        payerReports_[0] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
            payersMerkleRoot: 0,
            nodeIds: nodeIdsContainingNode1_
        });

        payerReports_[1] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 0,
            offset: 0,
            isSettled: true,
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

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = new IPayerReportManagerLike.PayerReport[](2);

        payerReports_[0] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 100,
            offset: 0,
            isSettled: true,
            payersMerkleRoot: 0,
            nodeIds: nodeIds_
        });

        payerReports_[1] = IPayerReportManagerLike.PayerReport({
            startSequenceId: 0,
            endSequenceId: 0,
            feesSettled: 200,
            offset: 0,
            isSettled: true,
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
        emit IDistributionManager.Claim(1, 2, 0, uint96(100) / 3);
        emit IDistributionManager.Claim(1, 3, 1, uint96(200) / 3);

        vm.prank(_alice);
        uint96 claimed_ = _manager.claim(1, originatorNodeIds_, payerReportIndices_);

        assertEq(claimed_, (uint96(100) / 3) + (uint96(200) / 3));
        assertEq(_manager.getOwedFees(1), 300 + claimed_);
        assertEq(_manager.totalOwedFees(), 500 + claimed_);
        assertEq(_manager.getHasClaimed(1, 2, 0), true);
        assertEq(_manager.getHasClaimed(1, 3, 1), true);
    }

    // TODO: Maybe a fuzz test for claim.

    /* ============ withdraw ============ */

    function test_withdraw_zeroDestination() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.ZeroDestination.selector);

        _manager.withdraw(1, address(0));
    }

    function test_withdraw_notNodeOwner() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.NotNodeOwner.selector);

        vm.prank(_bob);
        _manager.withdraw(1, _bob);
    }

    function test_withdraw_noFeesOwed() external {
        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        vm.expectRevert(IDistributionManager.NoFeesOwed.selector);

        vm.prank(_alice);
        _manager.withdraw(1, _alice);
    }

    function test_withdraw_zeroAvailableBalance() external {
        _manager.__setOwedFees(1, 3);

        vm.mockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));
        vm.mockCall(_token, abi.encodeWithSignature("balanceOf(address)", address(_manager)), abi.encode(0));
        vm.mockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

        vm.expectRevert(IDistributionManager.ZeroAvailableBalance.selector);

        vm.prank(_alice);
        _manager.withdraw(1, _alice);
    }

    function test_withdraw_partial_noPayerRegistryExcess() external {
        _manager.__setOwedFees(1, 10);
        _manager.__setTotalOwedFees(20);

        Utils.expectAndMockCall(_nodeRegistry, abi.encodeWithSignature("ownerOf(uint256)", 1), abi.encode(_alice));

        Utils.expectAndMockCall(
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(0));

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
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
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
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(5)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(3));

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
            _token,
            abi.encodeWithSignature("balanceOf(address)", address(_manager)),
            abi.encode(10)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("sendExcessToFeeDistributor()"), abi.encode(5));

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
                _token,
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
        _manager.__setHasClaimed(1, 2, 0, true);

        address newImplementation_ = address(
            new DistributionManagerHarness(
                _parameterRegistry,
                _nodeRegistry,
                _payerReportManager,
                _payerRegistry,
                _token
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
        assertEq(_manager.token(), _token);

        assertEq(_manager.getOwedFees(1), 2);
        assertEq(_manager.getHasClaimed(1, 2, 0), true);
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

    /* ============ getHasClaimed ============ */

    function test_getHasClaimed() external {
        _manager.__setHasClaimed(1, 2, 0, true);
        _manager.__setHasClaimed(1, 2, 1, false);
        _manager.__setHasClaimed(1, 3, 0, true);

        _manager.__setHasClaimed(2, 2, 0, false);
        _manager.__setHasClaimed(2, 2, 1, true);
        _manager.__setHasClaimed(2, 3, 0, false);

        assertEq(_manager.getHasClaimed(1, 2, 0), true);
        assertEq(_manager.getHasClaimed(1, 2, 1), false);
        assertEq(_manager.getHasClaimed(1, 3, 0), true);

        assertEq(_manager.getHasClaimed(2, 2, 0), false);
        assertEq(_manager.getHasClaimed(2, 2, 1), true);
        assertEq(_manager.getHasClaimed(2, 3, 0), false);
    }
}
