// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IAppChainGatewayLike } from "../../src/settlement-chain/interfaces/External.sol";

import { SettlementChainGatewayHarness } from "../utils/Harnesses.sol";

import {
    MockParameterRegistry,
    MockErc20,
    MockERC20Inbox,
    MockMigrator,
    MockFailingMigrator
} from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract SettlementChainGatewayTests is Test, Utils {
    bytes internal constant _DELIMITER = ".";
    bytes internal constant _MIGRATOR_KEY = "xmtp.settlementChainGateway.migrator";

    SettlementChainGatewayHarness internal _gateway;

    address internal _implementation;
    address internal _parameterRegistry;
    address internal _appChainNativeToken;

    address internal _appChainGateway = makeAddr("appChainGateway");
    address internal _alice = makeAddr("alice");

    function setUp() external {
        _parameterRegistry = address(new MockParameterRegistry());
        _appChainNativeToken = address(new MockErc20());

        _implementation = address(
            new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, _appChainNativeToken)
        );

        _gateway = SettlementChainGatewayHarness(
            address(
                new ERC1967Proxy(_implementation, abi.encodeWithSelector(ISettlementChainGateway.initialize.selector))
            )
        );
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistryAddress() external {
        vm.expectRevert(ISettlementChainGateway.ZeroParameterRegistryAddress.selector);
        new SettlementChainGatewayHarness(address(0), address(0), address(0));
    }

    function test_constructor_zeroAppChainGatewayAddress() external {
        vm.expectRevert(ISettlementChainGateway.ZeroAppChainGatewayAddress.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, address(0), _appChainNativeToken);
    }

    function test_constructor_zeroAppChainNativeTokenAddress() external {
        vm.expectRevert(ISettlementChainGateway.ZeroAppChainNativeTokenAddress.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, address(0));
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _gateway.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(_getImplementationFromSlot(address(_gateway)), _implementation);
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
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_gateway), 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositSenderFunds(address(0), 100);
    }

    function test_depositSenderFunds_transferFailed_tokenReverts() external {
        vm.mockCallRevert(
            _appChainNativeToken,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_gateway), 100),
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
            abi.encodeWithSelector(MockErc20.approve.selector, inbox_, 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.ApproveFailed.selector);

        _gateway.depositSenderFunds(inbox_, 100);
    }

    function test_depositSenderFunds_approveFailed_tokenReverts() external {
        address inbox_ = makeAddr("inbox");

        vm.mockCallRevert(_appChainNativeToken, abi.encodeWithSelector(MockErc20.approve.selector, inbox_, 100), "");

        vm.expectRevert(ISettlementChainGateway.ApproveFailed.selector);

        _gateway.depositSenderFunds(inbox_, 100);
    }

    function test_depositSenderFunds() external {
        address inbox_ = address(new MockERC20Inbox());

        vm.expectCall(
            _appChainNativeToken,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_gateway), 100)
        );

        vm.expectCall(_appChainNativeToken, abi.encodeWithSelector(MockErc20.approve.selector, inbox_, 100));
        _expectAndMockCall(inbox_, abi.encodeWithSelector(MockERC20Inbox.depositERC20.selector, 100), abi.encode(11));

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
        inboxes_[0] = address(new MockERC20Inbox());
        inboxes_[1] = address(new MockERC20Inbox());

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        _expectAndMockCall(
            inboxes_[0],
            abi.encodeWithSelector(
                MockERC20Inbox.sendContractTransaction.selector,
                100_000,
                1_000_000,
                _appChainGateway,
                0,
                abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_))
            ),
            abi.encode(uint256(11))
        );

        _expectAndMockCall(
            inboxes_[1],
            abi.encodeWithSelector(
                MockERC20Inbox.sendContractTransaction.selector,
                100_000,
                1_000_000,
                _appChainGateway,
                0,
                abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_))
            ),
            abi.encode(uint256(22))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.ParametersSent(inboxes_[0], 11, 1, keys_);

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.ParametersSent(inboxes_[1], 22, 1, keys_);

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
        inboxes_[0] = address(new MockERC20Inbox());
        inboxes_[1] = address(new MockERC20Inbox());

        bytes[] memory keys_ = new bytes[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.applyL1ToL2Alias(address(_gateway));

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(bytes[])", keys_), abi.encode(values_));

        _expectAndMockCall(
            inboxes_[0],
            abi.encodeWithSelector(
                MockERC20Inbox.createRetryableTicket.selector,
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
            abi.encode(uint256(11))
        );

        _expectAndMockCall(
            inboxes_[1],
            abi.encodeWithSelector(
                MockERC20Inbox.createRetryableTicket.selector,
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
            abi.encode(uint256(22))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.ParametersSent(inboxes_[0], 11, 1, keys_);

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.ParametersSent(inboxes_[1], 22, 1, keys_);

        _gateway.sendParametersAsRetryableTickets(inboxes_, keys_, 100_000, 1_000_000, 2_000_000, 3_000_000);

        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _gateway.migrate();
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

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        _mockParameterRegistryCall(_MIGRATOR_KEY, address(1));

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

        // TODO: `_expectAndMockParameterRegistryCall`.
        _mockParameterRegistryCall(_MIGRATOR_KEY, migrator_);

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(_getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.parameterRegistry(), newParameterRegistry_);
        assertEq(_gateway.appChainGateway(), newAppChainGateway_);
        assertEq(_gateway.appChainNativeToken(), newAppChainNativeToken_);
    }

    /* ============ appChainAlias ============ */

    function test_appChainAlias() external view {
        assertEq(_gateway.appChainAlias(), AddressAliasHelper.applyL1ToL2Alias(address(_gateway)));
    }

    /* ============ helper functions ============ */

    function _expectAndMockCall(address callee_, bytes memory data_, bytes memory returnData_) internal {
        vm.expectCall(callee_, data_);
        vm.mockCall(callee_, data_, returnData_);
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
