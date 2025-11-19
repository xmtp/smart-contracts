// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";

import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { AppChainGatewayHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract AppChainGatewayTests is Test {
    address internal constant _ARB_SYS = 0x0000000000000000000000000000000000000064; // address(100)

    string internal constant _DELIMITER = ".";
    string internal constant _MIGRATOR_KEY = "xmtp.appChainGateway.migrator";
    string internal constant _PAUSED_KEY = "xmtp.appChainGateway.paused";

    AppChainGatewayHarness internal _gateway;

    address internal _implementation;

    address internal _alice = makeAddr("alice");

    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _settlementChainGateway = makeAddr("settlementChainGateway");
    address internal _settlementChainGatewayAlias = AddressAliasHelper.toAlias(_settlementChainGateway);

    function setUp() external {
        _implementation = address(new AppChainGatewayHarness(_parameterRegistry, _settlementChainGateway));
        _gateway = AppChainGatewayHarness(address(new Proxy(_implementation)));

        _gateway.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IAppChainGateway.ZeroParameterRegistry.selector);
        new AppChainGatewayHarness(address(0), address(0));
    }

    function test_constructor_zeroSettlementChainGateway() external {
        vm.expectRevert(IAppChainGateway.ZeroSettlementChainGateway.selector);
        new AppChainGatewayHarness(_parameterRegistry, address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _gateway.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_gateway)), _implementation);
        assertEq(_gateway.implementation(), _implementation);
        assertEq(_gateway.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_gateway.pausedParameterKey(), _PAUSED_KEY);
        assertEq(_gateway.parameterRegistry(), _parameterRegistry);
        assertEq(_gateway.settlementChainGateway(), _settlementChainGateway);
        assertEq(_gateway.settlementChainGatewayAlias(), _settlementChainGatewayAlias);
        assertFalse(_gateway.paused());
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_gateway.version(), "1.0.0");
    }

    /* ============ contractName ============ */

    function test_contractName() external view {
        assertEq(_gateway.contractName(), "AppChainGateway");
    }

    /* ============ withdraw ============ */

    function test_withdraw_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(IAppChainGateway.Paused.selector);
        _gateway.withdraw(address(0));
    }

    function test_withdraw_zeroRecipient() external {
        vm.expectRevert(IAppChainGateway.ZeroRecipient.selector);
        _gateway.withdraw{ value: 0 }(address(0));
    }

    function test_withdraw_zeroWithdrawalAmount() external {
        vm.expectRevert(IAppChainGateway.ZeroWithdrawalAmount.selector);
        _gateway.withdraw{ value: 0 }(address(1));
    }

    function test_withdraw_noArbSys() external {
        vm.expectRevert();
        _gateway.withdraw{ value: 1 }(address(1));
    }

    function test_withdraw_arbSysRevert() external {
        vm.mockCallRevert(
            _ARB_SYS,
            abi.encodeWithSignature(
                "sendTxToL1(address,bytes)",
                _settlementChainGateway,
                abi.encodeWithSignature("receiveWithdrawal(address)", address(1))
            ),
            ""
        );

        vm.expectRevert();

        _gateway.withdraw{ value: 1 }(address(1));
    }

    function test_withdraw() external {
        vm.deal(_alice, 2);

        Utils.expectAndMockCall(
            _ARB_SYS,
            abi.encodeWithSignature(
                "sendTxToL1(address,bytes)",
                _settlementChainGateway,
                abi.encodeWithSignature("receiveWithdrawal(address)", address(1))
            ),
            abi.encode(11)
        );

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.Withdrawal(11, address(1), 1);

        vm.prank(_alice);
        _gateway.withdraw{ value: 1 }(address(1));

        assertEq(_alice.balance, 1);
    }

    /* ============ withdrawIntoUnderlying ============ */

    function test_withdrawIntoUnderlying_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(IAppChainGateway.Paused.selector);
        _gateway.withdrawIntoUnderlying(address(0));
    }

    function test_withdrawIntoUnderlying_zeroRecipient() external {
        vm.expectRevert(IAppChainGateway.ZeroRecipient.selector);
        _gateway.withdrawIntoUnderlying{ value: 0 }(address(0));
    }

    function test_withdrawIntoUnderlying_zeroWithdrawalAmount() external {
        vm.expectRevert(IAppChainGateway.ZeroWithdrawalAmount.selector);
        _gateway.withdrawIntoUnderlying{ value: 0 }(address(1));
    }

    function test_withdrawIntoUnderlying_noArbSys() external {
        vm.expectRevert();
        _gateway.withdrawIntoUnderlying{ value: 1 }(address(1));
    }

    function test_withdrawIntoUnderlying_arbSysRevert() external {
        vm.mockCallRevert(
            _ARB_SYS,
            abi.encodeWithSignature(
                "sendTxToL1(address,bytes)",
                _settlementChainGateway,
                abi.encodeWithSignature("receiveWithdrawalIntoUnderlying(address)", address(1))
            ),
            ""
        );

        vm.expectRevert();

        _gateway.withdrawIntoUnderlying{ value: 1 }(address(1));
    }

    function test_withdrawIntoUnderlying() external {
        vm.deal(_alice, 2);

        Utils.expectAndMockCall(
            _ARB_SYS,
            abi.encodeWithSignature(
                "sendTxToL1(address,bytes)",
                _settlementChainGateway,
                abi.encodeWithSignature("receiveWithdrawalIntoUnderlying(address)", address(1))
            ),
            abi.encode(11)
        );

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.Withdrawal(11, address(1), 1);

        vm.prank(_alice);
        _gateway.withdrawIntoUnderlying{ value: 1 }(address(1));

        assertEq(_alice.balance, 1);
    }

    /* ============ receiveDeposit ============ */

    function test_receiveDeposit_transferFailed() external {
        deal(_settlementChainGatewayAlias, 1);

        vm.mockCallRevert(address(1), bytes(""), "");

        vm.expectRevert(IAppChainGateway.TransferFailed.selector);

        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveDeposit{ value: 1 }(address(1));

        assertEq(_settlementChainGatewayAlias.balance, 1);
        assertEq(address(_gateway).balance, 0);
        assertEq(address(1).balance, 0);
    }

    function test_receiveDeposit() external {
        deal(_settlementChainGatewayAlias, 1);

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.DepositReceived(address(1), 1);

        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveDeposit{ value: 1 }(address(1));

        assertEq(_settlementChainGatewayAlias.balance, 0);
        assertEq(address(_gateway).balance, 0);
        assertEq(address(1).balance, 1);
    }

    /* ============ receiveParameters ============ */

    function test_receiveParameters_notSettlementChainGateway() external {
        vm.expectRevert(IAppChainGateway.NotSettlementChainGateway.selector);
        _gateway.receiveParameters(0, new string[](0), new bytes32[](0));
    }

    function test_receiveParameters() external {
        _gateway.__setKeyNonce("this.is.a.skipped.parameter", 1);

        string[] memory keys_ = new string[](3);

        keys_[0] = "this.is.a.used.parameter";
        keys_[1] = "this.is.a.skipped.parameter";
        keys_[2] = "this.is.another.used.parameter";

        bytes32[] memory values_ = new bytes32[](3);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));
        values_[2] = bytes32(uint256(98765));

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("set(string,bytes32)", keys_[0], values_[0]),
            ""
        );

        // NOTE: (keys_[1], values_[1]) is skipped because the nonce is lower than the key's nonce.

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("set(string,bytes32)", keys_[2], values_[2]),
            ""
        );

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.ParametersReceived(1, keys_);

        vm.prank(_settlementChainGatewayAlias);
        _gateway.receiveParameters(1, keys_, values_);

        assertEq(_gateway.__getKeyNonce("this.is.a.used.parameter"), 1);
        assertEq(_gateway.__getKeyNonce("this.is.a.skipped.parameter"), 1);
        assertEq(_gateway.__getKeyNonce("this.is.another.used.parameter"), 1);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(IAppChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.__setPauseStatus(true);

        vm.expectRevert(IAppChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.updatePauseStatus();

        assertTrue(_gateway.paused());

        vm.expectEmit(address(_gateway));
        emit IAppChainGateway.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        _gateway.updatePauseStatus();

        assertFalse(_gateway.paused());
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _gateway.migrate();
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

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newSettlementChainGateway_ = makeAddr("newSettlementChainGateway");

        address newImplementation_ = address(
            new AppChainGatewayHarness(newParameterRegistry_, newSettlementChainGateway_)
        );

        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.parameterRegistry(), newParameterRegistry_);
        assertEq(_gateway.settlementChainGateway(), newSettlementChainGateway_);
    }
}
