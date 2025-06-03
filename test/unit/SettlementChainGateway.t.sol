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
    bytes internal constant _INBOX_KEY = "xmtp.settlementChainGateway.inbox";
    bytes internal constant _MIGRATOR_KEY = "xmtp.settlementChainGateway.migrator";
    bytes internal constant _PAUSED_KEY = "xmtp.settlementChainGateway.paused";

    SettlementChainGatewayHarness internal _gateway;

    address internal _implementation;

    address internal _appChainGateway = makeAddr("appChainGateway");
    address internal _feeToken = makeAddr("feeToken");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _underlyingFeeToken = makeAddr("underlyingFeeToken");

    address internal _alice = makeAddr("alice");

    function setUp() external {
        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("underlying()"), abi.encode(_underlyingFeeToken));

        _implementation = address(new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, _feeToken));
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
        new SettlementChainGatewayHarness(_parameterRegistry, address(0), _feeToken);
    }

    function test_constructor_zeroFeeToken() external {
        vm.expectRevert(ISettlementChainGateway.ZeroFeeToken.selector);
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
        assertEq(_gateway.inboxParameterKey(), _INBOX_KEY);
        assertEq(_gateway.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_gateway.pausedParameterKey(), _PAUSED_KEY);
        assertEq(_gateway.parameterRegistry(), _parameterRegistry);
        assertEq(_gateway.appChainGateway(), _appChainGateway);
        assertEq(_gateway.feeToken(), _feeToken);
        assertFalse(_gateway.paused());
        assertEq(_gateway.__getNonce(), 0);
        assertEq(_gateway.__getUnderlyingFeeToken(), _underlyingFeeToken);
    }

    /* ============ deposit ============ */

    function test_deposit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.deposit(0, 0);
    }

    function test_deposit_feeTokenTransferFailed_reverts() external {
        _gateway.__setInbox(1111, makeAddr("inbox"));

        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.deposit(1111, 100);
    }

    function test_deposit_unsupportedChainId() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.deposit(1111, 100);
    }

    function test_deposit_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        _gateway.deposit(1111, 100);
    }

    function test_deposit() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(inbox_, abi.encodeWithSignature("depositERC20(uint256)", 100), abi.encode(11));

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, inbox_, 11, 100);

        vm.prank(_alice);
        _gateway.deposit(1111, 100);
    }

    /* ============ depositFromUnderlying ============ */

    function test_depositFromUnderlying_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.depositFromUnderlying(0, 0);
    }

    function test_depositFromUnderlying_underlyingTokenTransferFailed_returnsFalse() external {
        _gateway.__setInbox(1111, makeAddr("inbox"));

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, 100);
    }

    function test_depositFromUnderlying_underlyingTokenTransferFailed_reverts() external {
        _gateway.__setInbox(1111, makeAddr("inbox"));

        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, 100);
    }

    function test_depositFromUnderlying_feeTokenDepositFailed_reverts() external {
        _gateway.__setInbox(1111, makeAddr("inbox"));

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, 100);
    }

    function test_depositFromUnderlying_unsupportedChainId() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, 100);
    }

    function test_depositFromUnderlying_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        _gateway.depositFromUnderlying(1111, 100);
    }

    function test_depositFromUnderlying() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, 100),
            abi.encode(true)
        );

        Utils.expectAndMockCall(inbox_, abi.encodeWithSignature("depositERC20(uint256)", 100), abi.encode(11));

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, inbox_, 11, 100);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, 100);
    }

    /* ============ sendParameters ============ */

    function test_sendParameters_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParameters(new uint256[](0), new bytes[](0), 0, 0);
    }

    function test_sendParameters_noChainIds() external {
        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);
        _gateway.sendParameters(new uint256[](0), new bytes[](0), 0, 0);
    }

    function test_sendParameters_noKeys() external {
        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);
        _gateway.sendParameters(new uint256[](1), new bytes[](0), 0, 0);
    }

    function test_sendParameters_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        _gateway.sendParameters(chainIds_, keys_, 0, 0);
    }

    function test_sendParameters() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
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
            emit ISettlementChainGateway.ParametersSent(
                chainIds_[index_],
                inboxes_[index_],
                11 * (index_ + 1),
                1,
                keys_
            );
        }

        _gateway.sendParameters(chainIds_, keys_, 100_000, 1_000_000);

        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ sendParametersAsRetryableTickets ============ */

    function test_sendParametersAsRetryableTickets_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParametersAsRetryableTickets(new uint256[](0), new bytes[](0), 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets_noChainIds() external {
        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);
        _gateway.sendParametersAsRetryableTickets(new uint256[](0), new bytes[](0), 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets_noKeys() external {
        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);
        _gateway.sendParametersAsRetryableTickets(new uint256[](1), new bytes[](0), 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        _gateway.sendParametersAsRetryableTickets(chainIds_, keys_, 0, 0, 0, 0);
    }

    function test_sendParametersAsRetryableTickets() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                _feeToken,
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
            emit ISettlementChainGateway.ParametersSent(
                chainIds_[index_],
                inboxes_[index_],
                11 * (index_ + 1),
                1,
                keys_
            );
        }

        vm.prank(_alice);
        _gateway.sendParametersAsRetryableTickets(chainIds_, keys_, 100_000, 1_000_000, 2_000_000, 3_000_000);

        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ updateInbox ============ */

    function test_updateInbox() external {
        address inbox_ = makeAddr("inbox");

        vm.mockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", abi.encodePacked(_INBOX_KEY, ".1111")),
            abi.encode(bytes32(uint256(uint160(inbox_))))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.InboxUpdated(1111, inbox_);

        _gateway.updateInbox(1111);

        assertEq(_gateway.__getInbox(1111), inbox_);

        vm.mockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(bytes)", abi.encodePacked(_INBOX_KEY, ".1111")),
            abi.encode(0)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.InboxUpdated(1111, address(0));

        _gateway.updateInbox(1111);

        assertEq(_gateway.__getInbox(1111), address(0));
    }

    /* ============ withdraw ============ */

    function test_withdraw_feeTokenTransferFailed_reverts() external {
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_gateway)), abi.encode(100));

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("transfer(address,uint256)", _alice, 100), "");

        vm.expectRevert();

        _gateway.withdraw(_alice);
    }

    function test_withdraw() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_gateway)),
            abi.encode(100)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Withdrawal(100, _alice);

        uint256 amount_ = _gateway.withdraw(_alice);

        assertEq(amount_, 100);
    }

    /* ============ withdrawIntoUnderlying ============ */

    function test_withdrawIntoUnderlying_feeTokenWithdrawToFailed_reverts() external {
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_gateway)), abi.encode(100));

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 100), "");

        vm.expectRevert();

        _gateway.withdrawIntoUnderlying(_alice);
    }

    function test_withdrawIntoUnderlying() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_gateway)),
            abi.encode(100)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Withdrawal(100, _alice);

        uint256 amount_ = _gateway.withdrawIntoUnderlying(_alice);

        assertEq(amount_, 100);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(ISettlementChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.updatePauseStatus();

        assertTrue(_gateway.paused());

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.PauseStatusUpdated(false);

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
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(uint160(1))));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newAppChainGateway_ = makeAddr("newAppChainGateway");
        address newFeeToken_ = makeAddr("newFeeToken");

        Utils.expectAndMockCall(newFeeToken_, abi.encodeWithSignature("underlying()"), abi.encode(_underlyingFeeToken));

        address newImplementation_ = address(
            new SettlementChainGatewayHarness(newParameterRegistry_, newAppChainGateway_, newFeeToken_)
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
        assertEq(_gateway.feeToken(), newFeeToken_);
    }

    /* ============ getInbox ============ */

    function test_getInbox_unsupportedChainId() external {
        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));
        _gateway.getInbox(1111);
    }

    function test_getInbox() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        assertEq(_gateway.getInbox(1111), inbox_);
    }

    /* ============ appChainAlias ============ */

    function test_appChainAlias() external view {
        assertEq(_gateway.appChainAlias(), AddressAliasHelper.toAlias(address(_gateway)));
    }
}
