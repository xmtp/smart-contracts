// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, Vm } from "../../lib/forge-std/src/Test.sol";
import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IAppChainParameterRegistry } from "../../src/app-chain/interfaces/IAppChainParameterRegistry.sol";
import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";

import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";
import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";
import { AppChainParameterRegistryDeployer } from "../../script/deployers/AppChainParameterRegistryDeployer.sol";
import { AppChainGatewayDeployer } from "../../script/deployers/AppChainGatewayDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "../../script/deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "../../script/deployers/IdentityUpdateBroadcasterDeployer.sol";

import { IERC20Like, IBridgeLike, IERC20InboxLike, IArbRetryableTxPrecompileLike } from "./Interfaces.sol";

contract DeploymentTests is Test {
    error MessageDataHashMismatch(uint256 messageNumber_);
    error UnexpectedInbox(address inbox_);
    error UnexpectedMessageKind(uint8 kind_);

    address internal constant _SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN = 0xd06d8E471F0EeB1bb516303EdE399d004Acb1615;
    address internal constant _SETTLEMENT_CHAIN_BRIDGE = 0xC071180104924cC51922259a13B0d2DBF9646509;
    address internal constant _APPCHAIN_NATIVE_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address internal constant _APPCHAIN_RETRYABLE_TX_PRECOMPILE = 0x000000000000000000000000000000000000006E;

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.maxPayloadSize";

    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = bytes32(uint256(0));
    bytes32 internal constant _GATEWAY_PROXY_SALT = bytes32(uint256(1));
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = bytes32(uint256(2));
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = bytes32(uint256(3));

    uint8 internal constant _RETRYABLE_TICKET_KIND = 9;

    address internal _admin = makeAddr("admin");
    address internal _alice = makeAddr("alice");

    uint256 internal _baseForkId;
    uint256 internal _appchainForkId;

    IFactory internal _settlementChainFactory;
    IFactory internal _appChainFactory;

    ISettlementChainParameterRegistry internal _settlementChainParameterRegistryProxy;
    IAppChainParameterRegistry internal _appChainParameterRegistryProxy;

    ISettlementChainGateway internal _settlementChainGatewayProxy;
    IAppChainGateway internal _appChainGatewayProxy;

    IGroupMessageBroadcaster internal _groupMessageBroadcasterProxy;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcasterProxy;

    function setUp() external {
        vm.recordLogs();

        _baseForkId = vm.createFork("base_sepolia");
        _appchainForkId = vm.createFork("xmtp_testnet");

        _giveTokens(_alice, 10_000000); // 10 USDC
    }

    function test_deployProtocol() external {
        // Deploy the Factory on the base (settlement) chain.
        _settlementChainFactory = _deploySettlementChainFactory();

        // Deploy the Parameter Registry on the base (settlement) chain.
        address settlementChainParameterRegistryImplementation_ = _deploySettlementChainParameterRegistryImplementation();

        // The admin of the Parameter Registry on the base (settlement) chain is the global admin.
        _settlementChainParameterRegistryProxy = _deploySettlementChainParameterRegistryProxy(
            settlementChainParameterRegistryImplementation_,
            _admin
        );

        // Get the expected address of the Gateway on the base (settlement) chain, since the Gateway on the xmtp
        // (appchain) will need it.
        address expectedSettlementGatewayProxy_ = _expectedSettlementGatewayProxy();

        // Deploy the Factory on the xmtp (appchain) chain.
        _appChainFactory = _deployAppChainFactory();

        // Deploy the Parameter Registry on the xmtp (appchain) chain.
        address appChainParameterRegistryImplementation_ = _deployAppChainParameterRegistryImplementation();

        // Get the expected address of the Gateway on the xmtp (appchain) chain, since the Parameter Registry on the
        // same chain will need it.
        address expectedAppchainGatewayProxy_ = _expectedAppchainGatewayProxy();

        // The admin of the Parameter Registry on the xmtp (appchain) chain is the Gateway on the same chain.
        _appChainParameterRegistryProxy = _deployAppChainParameterRegistryProxy(
            appChainParameterRegistryImplementation_,
            expectedAppchainGatewayProxy_
        );

        // Deploy the Gateway on the xmtp (appchain) chain.
        address appChainGatewayImplementation_ = _deployAppChainGatewayImplementation(
            address(_appChainParameterRegistryProxy),
            expectedSettlementGatewayProxy_
        );

        _appChainGatewayProxy = _deployAppChainGatewayProxy(appChainGatewayImplementation_);

        // Deploy the Gateway on the base (settlement) chain.
        address settlementChainGatewayImplementation_ = _deploySettlementChainGatewayImplementation(
            address(_settlementChainParameterRegistryProxy),
            address(_appChainGatewayProxy)
        );

        _settlementChainGatewayProxy = _deploySettlementChainGatewayProxy(settlementChainGatewayImplementation_);

        // Set the parameters as need for the Group Message Broadcaster and Identity Update Broadcaster.
        _setBroadcasterStartingParameters();

        // Bridge the parameters from the base (settlement) chain to the xmtp (appchain) chain.
        _bridgeBroadcasterStartingParameters();

        // Handle the retryable ticket events as the sequencer to send messages to the xmtp (appchain) chain.
        _handleQueuedBridgeEvents();

        // Assert that the parameters were bridged from the base (settlement) chain to the xmtp (appchain) chain.
        _assertBroadcasterStartingParameters();

        // Deploy the Group Message Broadcaster on the xmtp (appchain) chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            address(_appChainParameterRegistryProxy)
        );

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        // Deploy the Identity Update Broadcaster on the xmtp (appchain) chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            address(_appChainParameterRegistryProxy)
        );

        _identityUpdateBroadcasterProxy = _deployIdentityUpdateBroadcasterProxy(
            identityUpdateBroadcasterImplementation_
        );
    }

    /* ============ Factory Deployer Helpers ============ */

    function _deploySettlementChainFactory() internal returns (IFactory factory_) {
        vm.selectFork(_baseForkId);
        return _deployFactory();
    }

    function _deployAppChainFactory() internal returns (IFactory factory_) {
        vm.selectFork(_appchainForkId);
        return _deployFactory();
    }

    function _deployFactory() internal returns (IFactory factory_) {
        vm.startPrank(_admin);
        factory_ = IFactory(FactoryDeployer.deploy());
        vm.stopPrank();
    }

    /* ============ Parameter Registry Deployer Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(
            address(_settlementChainFactory)
        );
        vm.stopPrank();
    }

    function _deployAppChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(address(_appChainFactory));
        vm.stopPrank();
    }

    function _deploySettlementChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (ISettlementChainParameterRegistry registry_) {
        vm.selectFork(_baseForkId);

        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startPrank(_admin);
        (address proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        registry_ = ISettlementChainParameterRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _deployAppChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (IAppChainParameterRegistry registry_) {
        vm.selectFork(_appchainForkId);

        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startPrank(_admin);
        (address proxy_, , ) = AppChainParameterRegistryDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        registry_ = IAppChainParameterRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Gateway Deployer Helpers ============ */

    function _deploySettlementChainGatewayImplementation(
        address parameterRegistry_,
        address appChainGateway_
    ) internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_,
            appChainGateway_,
            _APPCHAIN_NATIVE_TOKEN
        );
        vm.stopPrank();

        assertEq(ISettlementChainGateway(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(ISettlementChainGateway(implementation_).appChainGateway(), appChainGateway_);
        assertEq(ISettlementChainGateway(implementation_).appChainNativeToken(), _APPCHAIN_NATIVE_TOKEN);
    }

    function _deployAppChainGatewayImplementation(
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal returns (address implementation_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
            address(_appChainFactory),
            parameterRegistry_,
            settlementChainGateway_
        );
        vm.stopPrank();

        assertEq(IAppChainGateway(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IAppChainGateway(implementation_).settlementChainGateway(), settlementChainGateway_);

        assertEq(
            IAppChainGateway(implementation_).settlementChainGatewayAlias(),
            AddressAliasHelper.applyL1ToL2Alias(settlementChainGateway_)
        );
    }

    function _deploySettlementChainGatewayProxy(
        address implementation_
    ) internal returns (ISettlementChainGateway gateway_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        gateway_ = ISettlementChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    function _deployAppChainGatewayProxy(address implementation_) internal returns (IAppChainGateway gateway_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = AppChainGatewayDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        gateway_ = IAppChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    /* ============ Group Message Broadcaster Deployer Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
            address(_appChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IGroupMessageBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployGroupMessageBroadcasterProxy(
        address implementation_
    ) internal returns (IGroupMessageBroadcaster broadcaster_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _GROUP_MESSAGE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IGroupMessageBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Identity Update Broadcaster Deployer Helpers ============ */

    function _deployIdentityUpdateBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
            address(_appChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IIdentityUpdateBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployIdentityUpdateBroadcasterProxy(
        address implementation_
    ) internal returns (IIdentityUpdateBroadcaster broadcaster_) {
        vm.selectFork(_appchainForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Generic Deployer Helpers ============ */

    function _deployImplementation(
        IFactory factory_,
        bytes memory creationCode_
    ) internal returns (address implementation_) {
        vm.prank(_alice); // Anyone can deploy an implementation, it will always be the same address.
        return factory_.deployImplementation(creationCode_);
    }

    function _deployProxy(
        IFactory factory_,
        address implementation_,
        bytes32 salt_,
        bytes memory initializeCallData_
    ) internal returns (address proxy_) {
        vm.prank(_admin); // Proxies are deployed by the global admin.
        proxy_ = factory_.deployProxy(implementation_, salt_, initializeCallData_);

        assertEq(IERC1967(proxy_).implementation(), implementation_);
    }

    /* ============ Parameter Helpers ============ */

    function _setBroadcasterStartingParameters() internal {
        vm.selectFork(_baseForkId);

        bytes[] memory keys_ = new bytes[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[1] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);
        values_[2] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[3] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);

        vm.prank(_admin);
        _settlementChainParameterRegistryProxy.set(keys_, values_);

        assertEq(_settlementChainParameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _bridgeBroadcasterStartingParameters() internal {
        bytes[] memory keys_ = new bytes[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        _approveTokens(_alice, address(_settlementChainGatewayProxy), 1_000000);

        _sendParametersAsRetryableTickets(
            _alice,
            keys_,
            200_000,
            2_000_000_000, // 2 gwei
            1_000000, // 1 USDC
            1_000000 // 1 USDC
        );
    }

    function _sendParametersAsRetryableTickets(
        address account_,
        bytes[] memory keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) internal {
        vm.selectFork(_baseForkId);

        address[] memory inboxes_ = new address[](1);
        inboxes_[0] = _SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN;

        vm.prank(account_);
        _settlementChainGatewayProxy.sendParametersAsRetryableTickets(
            inboxes_,
            keys_,
            gasLimit_,
            gasPrice_,
            maxSubmissionCost_,
            nativeTokensToSend_
        );
    }

    function _assertBroadcasterStartingParameters() internal view {
        assertEq(
            uint256(_appChainParameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_appChainParameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_appChainParameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_appChainParameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    /* ============ Token Helpers ============ */

    function _giveTokens(address recipient_, uint256 amount_) internal {
        vm.selectFork(_baseForkId);
        deal(_APPCHAIN_NATIVE_TOKEN, recipient_, amount_);
    }

    function _approveTokens(address account_, address spender_, uint256 amount_) internal {
        vm.selectFork(_baseForkId);
        vm.prank(account_);
        IERC20Like(_APPCHAIN_NATIVE_TOKEN).approve(spender_, amount_);
    }

    /* ============ Bridge Helpers ============ */

    function _handleQueuedBridgeEvents() internal {
        vm.selectFork(_baseForkId);

        Vm.Log[] memory logs_ = vm.getRecordedLogs();

        for (uint256 index_; index_ < logs_.length; ++index_) {
            Vm.Log memory log_ = logs_[index_];

            if (log_.emitter != _SETTLEMENT_CHAIN_BRIDGE) continue; // Not a bridge event.

            if (log_.topics[0] != IBridgeLike.MessageDelivered.selector) continue; // Not a `MessageDelivered` event.

            // Try to match the `MessageDelivered` event to a `InboxMessageDelivered` event in `logs_`, and handle it.
            _handleMessageDeliveredEvent(log_, logs_);
        }
    }

    function _handleMessageDeliveredEvent(Vm.Log memory messageDeliveredLog_, Vm.Log[] memory logs_) internal {
        (
            uint256 messageIndex_,
            address inbox_,
            uint8 kind_,
            address sender_,
            bytes32 messageDataHash_,
            uint256 baseFeeL1_
        ) = _decodeMessageDeliveredEvent(messageDeliveredLog_);

        if (kind_ != _RETRYABLE_TICKET_KIND) return; // Not a retryable ticket. TODO: Handle other kinds of messages.

        for (uint256 index_; index_ < logs_.length; ++index_) {
            Vm.Log memory log_ = logs_[index_];

            if (log_.emitter != inbox_) continue;

            if (log_.topics[0] != IERC20InboxLike.InboxMessageDelivered.selector) continue;

            // Parse the `InboxMessageDelivered` event and handle it.
            // NOTE: `sender_` should already be aliased at this point, at least for retryable tickets.
            _handleInboxMessageDeliveredEvent(inbox_, messageIndex_, kind_, sender_, messageDataHash_, log_);
        }
    }

    function _handleInboxMessageDeliveredEvent(
        address inbox_,
        uint256 messageIndex_,
        uint8 kind_,
        address sender_,
        bytes32 messageDataHash_,
        Vm.Log memory inboxMessageDeliveredLog_
    ) internal {
        _selectForkForDelivery(inbox_);

        (uint256 messageNumber_, bytes memory data_) = _decodeInboxMessageDeliveredEvent(inboxMessageDeliveredLog_);

        if (messageNumber_ != messageIndex_) return; // Not the expected message number.

        if (keccak256(data_) != messageDataHash_) revert MessageDataHashMismatch(messageNumber_);

        _handleMessageDelivery(kind_, sender_, messageNumber_, data_);
    }

    function _selectForkForDelivery(address inbox_) internal {
        if (inbox_ == _SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN) {
            vm.selectFork(_appchainForkId);
        } else {
            revert UnexpectedInbox(inbox_);
        }
    }

    function _handleMessageDelivery(uint8 kind_, address sender_, uint256 messageNumber_, bytes memory data_) internal {
        if (kind_ == _RETRYABLE_TICKET_KIND) {
            _handleRetryableTicket(sender_, messageNumber_, data_);
        } else {
            revert UnexpectedMessageKind(kind_);
        }
    }

    function _handleRetryableTicket(address sender_, uint256 messageNumber_, bytes memory data_) internal {
        (
            address retryTo_,
            ,
            uint256 deposit_,
            uint256 maxSubmissionFee_,
            address refundAddress_,
            ,
            uint256 gasLimit_,
            uint256 gasFeeCap_,
            bytes memory retryData_
        ) = _decodeMessageData(data_);

        // NOTE: Cannot dfo this due to `InvalidFEOpcode` error as foundry likely doesn't support `ArbOS` opcodes.
        // _submitRetryable(
        //     sender_,
        //     bytes32(messageNumber_),
        //     deposit_,
        //     gasFeeCap_,
        //     uint64(gasLimit_),
        //     maxSubmissionFee_,
        //     refundAddress_,
        //     retryTo_,
        //     retryData_
        // );

        _call(sender_, retryTo_, retryData_);
    }

    function _submitRetryable(
        address account_,
        bytes32 requestId_,
        uint256 deposit_,
        uint256 gasFeeCap_,
        uint64 gasLimit_,
        uint256 maxSubmissionFee_,
        address refundAddress_,
        address retryTo_,
        bytes memory retryData_
    ) internal {
        vm.prank(account_);
        IArbRetryableTxPrecompileLike(_APPCHAIN_RETRYABLE_TX_PRECOMPILE).submitRetryable(
            requestId_,
            0,
            deposit_,
            0,
            gasFeeCap_,
            gasLimit_,
            maxSubmissionFee_,
            refundAddress_,
            refundAddress_,
            retryTo_,
            retryData_
        );
    }

    function _call(address sender_, address to_, bytes memory data_) internal {
        vm.prank(sender_);
        to_.call(data_);
    }

    /* ============ Bridge Event Decoders ============ */

    function _decodeMessageDeliveredEvent(
        Vm.Log memory log_
    )
        internal
        pure
        returns (
            uint256 messageIndex_,
            address inbox_,
            uint8 kind_,
            address sender_,
            bytes32 messageDataHash_,
            uint256 baseFeeL1_
        )
    {
        messageIndex_ = uint256(bytes32(log_.topics[1]));

        (inbox_, kind_, sender_, messageDataHash_, baseFeeL1_, ) = abi.decode(
            log_.data,
            (address, uint8, address, bytes32, uint256, uint64)
        );
    }

    function _decodeInboxMessageDeliveredEvent(
        Vm.Log memory log_
    ) internal pure returns (uint256 messageNum_, bytes memory data_) {
        messageNum_ = uint256(bytes32(log_.topics[1]));
        data_ = abi.decode(log_.data, (bytes));
    }

    function _decodeMessageData(
        bytes memory messageData_
    )
        internal
        pure
        returns (
            address to_,
            uint256 l2CallValue_,
            uint256 amount_,
            uint256 maxSubmissionCost_,
            address excessFeeRefundAddress_,
            address callValueRefundAddress_,
            uint256 gasLimit_,
            uint256 maxFeePerGas_,
            bytes memory data_
        )
    {
        assembly {
            to_ := mload(add(messageData_, 0x20))
            l2CallValue_ := mload(add(messageData_, 0x40))
            amount_ := mload(add(messageData_, 0x60))
            maxSubmissionCost_ := mload(add(messageData_, 0x80))
            excessFeeRefundAddress_ := mload(add(messageData_, 0xa0))
            callValueRefundAddress_ := mload(add(messageData_, 0xc0))
            gasLimit_ := mload(add(messageData_, 0xe0))
            maxFeePerGas_ := mload(add(messageData_, 0x100))
            let dataLength_ := mload(add(messageData_, 0x120))
            data_ := add(messageData_, 0x120)
            mstore(data_, dataLength_)
        }
    }

    /* ============ Expected Proxy Getters ============ */

    function _expectedSettlementGatewayProxy() internal returns (address expectedSettlementGatewayProxy_) {
        vm.selectFork(_baseForkId);
        return _settlementChainFactory.computeProxyAddress(_admin, _GATEWAY_PROXY_SALT);
    }

    function _expectedAppchainGatewayProxy() internal returns (address expectedAppchainGatewayProxy_) {
        vm.selectFork(_appchainForkId);
        return _appChainFactory.computeProxyAddress(_admin, _GATEWAY_PROXY_SALT);
    }
}
