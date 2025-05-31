// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";

import { IAppChainGatewayLike } from "../../src/settlement-chain/interfaces/External.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { SettlementChainGatewayHarness } from "../utils/Harnesses.sol";

import { MockMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract SettlementChainGatewayTests is Test {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _MIGRATOR_KEY = "xmtp.settlementChainGateway.migrator";

    SettlementChainGatewayHarness internal _gateway;

    address internal _implementation;

    address internal _appChainGateway = makeAddr("appChainGateway");
    address internal _appChainNativeToken = makeAddr("appChainNativeToken");
    address internal _parameterRegistry = makeAddr("parameterRegistry");

    address internal _alice = makeAddr("alice");

    function setUp() external {
        _implementation = address(
            new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, _appChainNativeToken)
        );

        _gateway = SettlementChainGatewayHarness(address(new Proxy(_implementation)));

        _gateway.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(ISettlementChainGateway.ZeroParameterRegistry.selector);
        new SettlementChainGatewayHarness(address(0), address(0), address(0));
    }

    function test_constructor_zeroAppChainGateway() external {
        vm.expectRevert(ISettlementChainGateway.ZeroAppChainGateway.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, address(0), _appChainNativeToken);
    }

    function test_constructor_zeroAppChainNativeToken() external {
        vm.expectRevert(ISettlementChainGateway.ZeroAppChainNativeToken.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, address(0));
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
        assertEq(keccak256(_gateway.migratorParameterKey()), keccak256(_MIGRATOR_KEY));
        assertEq(_gateway.parameterRegistry(), _parameterRegistry);
        assertEq(_gateway.appChainGateway(), _appChainGateway);
        assertEq(_gateway.appChainNativeToken(), _appChainNativeToken);
        assertEq(_gateway.__getNonce(), 0);
    }

    /* ============ depositSenderFunds ============ */

    function test_depositSenderFunds_transferFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _appChainNativeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositSenderFunds(address(0), 100);
    }

    function test_depositSenderFunds_transferFailed_tokenReverts() external {
        vm.mockCallRevert(
            _appChainNativeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositSenderFunds(address(0), 100);
    }

    function test_depositSenderFunds_approveFailed_tokenReturnsFalse() external {
        address inbox_ = makeAddr("inbox");

        vm.mockCall(
            _appChainNativeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.ApproveFailed.selector);

        _gateway.depositSenderFunds(inbox_, 100);
    }

    function test_depositSenderFunds_approveFailed_tokenReverts() external {
        address inbox_ = makeAddr("inbox");

        vm.mockCallRevert(_appChainNativeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert(ISettlementChainGateway.ApproveFailed.selector);

        _gateway.depositSenderFunds(inbox_, 100);
    }

    function test_depositSenderFunds() external {
        address inbox_ = makeAddr("inbox");

        Utils.expectAndMockCall(
            _appChainNativeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _appChainNativeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(inbox_, abi.encodeWithSignature("depositERC20(uint256)", 100), abi.encode(11));

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.SenderFundsDeposited(inbox_, 11, 100);

        vm.prank(_alice);
        _gateway.depositSenderFunds(inbox_, 100);
    }

    /* ============ sendParameters ============ */

    function test_sendParameters_noInboxes() external {
        vm.expectRevert(ISettlementChainGateway.NoInboxes.selector);
        _gateway.sendParameters(new address[](0), new bytes[](0), 0, 0);
    }

    function test_sendParameters_noKeys() external {
        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);
        _gateway.sendParameters(new address[](1), new bytes[](0), 0, 0);
    }

    function test_sendParameters() external {
        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "sendContractTransaction(uint256,uint256,address,uint256,bytes)",
                    100_000,
                    1_000_000,
                    _appChainGateway,
                    0,
                    abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_))
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(inboxes_[index_], 11 * (index_ + 1), 1, keys_);
        }

        _gateway.sendParameters(inboxes_, keys_, 100_000, 1_000_000);

        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ sendParametersAsRetryableTickets ============ */

    function test_sendParametersAsRetryableTickets_noInboxes() external {
        vm.expectRevert(ISettlementChainGateway.NoInboxes.selector);
        _gateway.sendParametersAsRetryableTickets(new address[](0), new bytes[](0), 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets_noKeys() external {
        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);
        _gateway.sendParametersAsRetryableTickets(new address[](1), new bytes[](0), 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets() external {
        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.applyL1ToL2Alias(address(_gateway));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        for (uint256 index_; index_ < inboxes_.length; ++index_) {
            Utils.expectAndMockCall(
                _appChainNativeToken,
                abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                _appChainNativeToken,
                abi.encodeWithSignature("approve(address,uint256)", inboxes_[index_], 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                    _appChainGateway,
                    0,
                    2_000_000,
                    appChainAlias_,
                    appChainAlias_,
                    100_000,
                    1_000_000,
                    3_000_000,
                    abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_))
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(inboxes_[index_], 11 * (index_ + 1), 1, keys_);
        }

        vm.prank(_alice);
        _gateway.sendParametersAsRetryableTickets(inboxes_, keys_, 100_000, 1_000_000, 2_000_000, 3_000_000);

        assertEq(_gateway.__getNonce(), 1);
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
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(uint160(1))));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newAppChainGateway_ = makeAddr("newAppChainGateway");
        address newAppChainNativeToken_ = makeAddr("newAppChainNativeToken");

        address newImplementation_ = address(
            new SettlementChainGatewayHarness(newParameterRegistry_, newAppChainGateway_, newAppChainNativeToken_)
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
        assertEq(_gateway.appChainGateway(), newAppChainGateway_);
        assertEq(_gateway.appChainNativeToken(), newAppChainNativeToken_);
    }

    /* ============ appChainAlias ============ */

    function test_appChainAlias() external view {
        assertEq(_gateway.appChainAlias(), AddressAliasHelper.applyL1ToL2Alias(address(_gateway)));
    }
}
