// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, Vm, console } from "../../lib/forge-std/src/Test.sol";

/* ============ Source Library Imports ============ */

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";

/* ============ Source Library Imports ============ */

import { ParameterKeys } from "../../src/libraries/ParameterKeys.sol";

/* ============ Source Interface Imports ============ */

import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IAppChainParameterRegistry } from "../../src/app-chain/interfaces/IAppChainParameterRegistry.sol";
import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IFeeToken } from "../../src/settlement-chain/interfaces/IFeeToken.sol";
import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

/* ============ Deployer Imports ============ */

import { AppChainGatewayDeployer } from "../../script/deployers/AppChainGatewayDeployer.sol";
import { AppChainParameterRegistryDeployer } from "../../script/deployers/AppChainParameterRegistryDeployer.sol";
import { DistributionManagerDeployer } from "../../script/deployers/DistributionManagerDeployer.sol";
import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import { FeeTokenDeployer } from "../../script/deployers/FeeTokenDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "../../script/deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "../../script/deployers/IdentityUpdateBroadcasterDeployer.sol";
import { MockUnderlyingFeeTokenDeployer } from "../../script/deployers/MockUnderlyingFeeTokenDeployer.sol";
import { NodeRegistryDeployer } from "../../script/deployers/NodeRegistryDeployer.sol";
import { PayerRegistryDeployer } from "../../script/deployers/PayerRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "../../script/deployers/PayerReportManagerDeployer.sol";
import { RateRegistryDeployer } from "../../script/deployers/RateRegistryDeployer.sol";
import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";

import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";

/* ============ Source Imports ============ */

import { Proxy } from "../../src/any-chain/Proxy.sol";

/* ============ Test Interface Imports ============ */

import { IERC20Like, IBridgeLike, IERC20InboxLike, IArbRetryableTxPrecompileLike } from "./Interfaces.sol";

/* ============ Test Contract Imports ============ */

import { MockUnderlyingFeeToken } from "../utils/Mocks.sol";

contract DeployTests is Test {
    error MessageDataHashMismatch(uint256 messageNumber_);
    error UnexpectedInbox(address inbox_);
    error UnexpectedMessageKind(uint8 kind_);

    address internal constant _SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN = 0xA382f402Cb702484B424AC8e2B7fEE9B032C6b9d;
    address internal constant _SETTLEMENT_CHAIN_BRIDGE = 0xD05baD3cec5E67152178F731aae8025fC1F2DAEA;
    address internal constant _APPCHAIN_RETRYABLE_TX_PRECOMPILE = 0x000000000000000000000000000000000000006E;

    address internal constant _ADMIN = 0x560469CBb7D1E29c7d56EfE765B21FbBaC639dC7;
    address internal constant _DEPLOYER = 0xD940Dd30F750162c12086C6dc68507F7e8C480B4;
    address internal constant _FEE_TOKEN = 0x63C6667798fdA65E2E29228C43fbfDa0Cd4634A8;
    address internal constant _SETTLEMENT_CHAIN_FACTORY = 0x9492Ea65F5f20B01Ed5eBe1b49f77208123585a1;
    address internal constant _SETTLEMENT_CHAIN_PARAMETER_REGISTRY = 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D;
    address internal constant _UNDERLYING_FEE_TOKEN = 0x2d7e0534183dAD09008C97f230d9F4f6425eE859;

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 75_000;
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000; // 2 gwei per gas.

    string internal constant _SETTLEMENT_CHAIN_GATEWAY_INBOX_KEY = "xmtp.settlementChainGateway.inbox";

    string internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    string internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.maxPayloadSize";

    string internal constant _PAYER_REGISTRY_SETTLER_KEY = "xmtp.payerRegistry.settler";
    string internal constant _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY = "xmtp.payerRegistry.feeDistributor";
    string internal constant _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY = "xmtp.payerRegistry.minimumDeposit";
    string internal constant _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY = "xmtp.payerRegistry.withdrawLockPeriod";

    string internal constant _RATE_REGISTRY_MESSAGE_FEE_KEY = "xmtp.rateRegistry.messageFee";
    string internal constant _RATE_REGISTRY_STORAGE_FEE_KEY = "xmtp.rateRegistry.storageFee";
    string internal constant _RATE_REGISTRY_CONGESTION_FEE_KEY = "xmtp.rateRegistry.congestionFee";
    string internal constant _RATE_REGISTRY_TARGET_RATE_PER_MINUTE_KEY = "xmtp.rateRegistry.targetRatePerMinute";

    string internal constant _NODE_REGISTRY_ADMIN_KEY = "xmtp.nodeRegistry.admin";
    string internal constant _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY = "xmtp.nodeRegistry.maxCanonicalNodes";

    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    uint256 internal constant _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT = 10_000000;
    uint256 internal constant _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD = 2 days;

    uint256 internal constant _RATE_REGISTRY_STARTING_MESSAGE_FEE = 100;
    uint256 internal constant _RATE_REGISTRY_STARTING_STORAGE_FEE = 200;
    uint256 internal constant _RATE_REGISTRY_STARTING_CONGESTION_FEE = 300;
    uint256 internal constant _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE = 100 * 60;

    uint256 internal constant _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES = 100;

    bytes32 internal constant _FEE_TOKEN_PROXY_SALT = "FeeToken_0";
    bytes32 internal constant _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT = "MockUnderlyingFeeToken_0";
    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = "ParameterRegistry_0";

    bytes32 internal constant _DISTRIBUTION_MANAGER_PROXY_SALT = "DistributionManager_0_0";
    bytes32 internal constant _GATEWAY_PROXY_SALT = "Gateway_0_0";
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = "GroupMessageBroadcaster_0_0";
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = "IdentityUpdateBroadcaster_0_0";
    bytes32 internal constant _NODE_REGISTRY_PROXY_SALT = "NodeRegistry_0_0";
    bytes32 internal constant _PAYER_REGISTRY_PROXY_SALT = "PayerRegistry_0_0";
    bytes32 internal constant _PAYER_REPORT_MANAGER_PROXY_SALT = "PayerReportManager_0_0";
    bytes32 internal constant _RATE_REGISTRY_PROXY_SALT = "RateRegistry_0_0";

    uint8 internal constant _RETRYABLE_TICKET_KIND = 9;

    address internal _alice = makeAddr("alice");

    uint256 internal _settlementChainForkId;
    uint256 internal _appChainForkId;

    uint256 internal _settlementChainId;
    uint256 internal _appChainId;

    IFactory internal _appChainFactory;

    IAppChainParameterRegistry internal _appChainParameterRegistryProxy;

    ISettlementChainGateway internal _settlementChainGatewayProxy;
    IAppChainGateway internal _appChainGatewayProxy;

    IGroupMessageBroadcaster internal _groupMessageBroadcasterProxy;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcasterProxy;

    IPayerRegistry internal _payerRegistryProxy;

    IRateRegistry internal _rateRegistryProxy;

    INodeRegistry internal _nodeRegistryProxy;

    IPayerReportManager internal _payerReportManagerProxy;

    IDistributionManager internal _distributionManagerProxy;

    function setUp() external {
        vm.recordLogs();

        _settlementChainForkId = vm.createSelectFork("base_sepolia");
        _settlementChainId = block.chainid;

        _appChainForkId = vm.createSelectFork("xmtp_ropsten");
        _appChainId = block.chainid;
    }

    function test_deployTestnetProtocol() external {
        // Get the expected address of the Gateway on the app chain, since the Parameter Registry on the
        // same chain will need it.
        address expectedGatewayProxy_ = _expectedGatewayProxy();

        // Deploy the Gateway on the settlement chain.
        address settlementChainGatewayImplementation_ = _deploySettlementChainGatewayImplementation(
            _SETTLEMENT_CHAIN_PARAMETER_REGISTRY,
            expectedGatewayProxy_,
            _FEE_TOKEN
        );

        console.log("settlementChainGatewayImplementation: %s", address(settlementChainGatewayImplementation_));

        _settlementChainGatewayProxy = _deploySettlementChainGatewayProxy(settlementChainGatewayImplementation_);

        console.log("settlementChainGatewayProxy: %s", address(_settlementChainGatewayProxy));

        // Deploy the Payer Registry on the settlement chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(
            _SETTLEMENT_CHAIN_PARAMETER_REGISTRY,
            _FEE_TOKEN
        );

        console.log("payerRegistryImplementation: %s", address(payerRegistryImplementation_));

        _payerRegistryProxy = _deployPayerRegistryProxy(payerRegistryImplementation_);

        console.log("payerRegistryProxy: %s", address(_payerRegistryProxy));

        // Deploy the Rate Registry on the settlement chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY);

        console.log("rateRegistryImplementation: %s", address(rateRegistryImplementation_));

        _rateRegistryProxy = _deployRateRegistryProxy(rateRegistryImplementation_);

        console.log("rateRegistryProxy: %s", address(_rateRegistryProxy));

        // Deploy the Node Registry on the settlement chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY);

        console.log("nodeRegistryImplementation: %s", address(nodeRegistryImplementation_));

        _nodeRegistryProxy = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        console.log("nodeRegistryProxy: %s", address(_nodeRegistryProxy));

        // Deploy the Payer Report Manager on the settlement chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            _SETTLEMENT_CHAIN_PARAMETER_REGISTRY,
            address(_nodeRegistryProxy),
            address(_payerRegistryProxy)
        );

        console.log("payerReportManagerImplementation: %s", address(payerReportManagerImplementation_));

        _payerReportManagerProxy = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        console.log("payerReportManagerProxy: %s", address(_payerReportManagerProxy));

        // Deploy the Distribution Manager on the settlement chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            _SETTLEMENT_CHAIN_PARAMETER_REGISTRY,
            address(_nodeRegistryProxy),
            address(_payerReportManagerProxy),
            address(_payerRegistryProxy),
            _FEE_TOKEN
        );

        console.log("distributionManagerImplementation: %s", address(distributionManagerImplementation_));

        _distributionManagerProxy = _deployDistributionManagerProxy(distributionManagerImplementation_);

        console.log("distributionManagerProxy: %s", address(_distributionManagerProxy));

        // Deploy the Factory on the app chain.
        _appChainFactory = _deployAppChainFactoryProxy(_getExpectedFactoryImplementation());

        console.log("appChainFactory: %s", address(_appChainFactory));

        address appChainFactoryImplementation_ = _deployAppChainFactoryImplementation(
            _getExpectedParameterRegistryProxy()
        );

        console.log("appChainFactoryImplementation: %s", appChainFactoryImplementation_);

        _initializeAppChainFactory(appChainFactoryImplementation_);

        console.log("appChainInitializableImplementation: %s", _appChainFactory.initializableImplementation());

        // Deploy the Parameter Registry on the app chain.
        address appChainParameterRegistryImplementation_ = _deployAppChainParameterRegistryImplementation();

        console.log("appChainParameterRegistryImplementation: %s", address(appChainParameterRegistryImplementation_));

        // The admin of the Parameter Registry on the app chain is the Gateway on the same chain.
        _appChainParameterRegistryProxy = _deployAppChainParameterRegistryProxy(
            appChainParameterRegistryImplementation_,
            expectedGatewayProxy_
        );

        console.log("appChainParameterRegistryProxy: %s", address(_appChainParameterRegistryProxy));

        // Deploy the Gateway on the app chain.
        address appChainGatewayImplementation_ = _deployAppChainGatewayImplementation(
            address(_appChainParameterRegistryProxy),
            address(_settlementChainGatewayProxy)
        );

        console.log("appChainGatewayImplementation: %s", address(appChainGatewayImplementation_));

        _appChainGatewayProxy = _deployAppChainGatewayProxy(appChainGatewayImplementation_);

        console.log("appChainGatewayProxy: %s", address(_appChainGatewayProxy));

        // Deploy the Group Message Broadcaster on the app chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            address(_appChainParameterRegistryProxy)
        );

        console.log("groupMessageBroadcasterImplementation: %s", address(groupMessageBroadcasterImplementation_));

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        console.log("groupMessageBroadcasterProxy: %s", address(_groupMessageBroadcasterProxy));

        // Deploy the Identity Update Broadcaster on the app chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            address(_appChainParameterRegistryProxy)
        );

        console.log("identityUpdateBroadcasterImplementation: %s", address(identityUpdateBroadcasterImplementation_));

        _identityUpdateBroadcasterProxy = _deployIdentityUpdateBroadcasterProxy(
            identityUpdateBroadcasterImplementation_
        );

        console.log("identityUpdateBroadcasterProxy: %s", address(_identityUpdateBroadcasterProxy));

        // Set and update the inbox parameters for the settlement chain gateway to communicate with the app chain.
        _setInboxParameters();
        _updateInboxParameters();

        // Set and update the parameters as needed for the Node Registry.
        _setNodeRegistryStartingParameters();
        _updateNodeRegistryStartingParameters();

        // Set and update the parameters as needed for the Payer Registry.
        _setPayerRegistryStartingParameters();
        _updatePayerRegistryStartingParameters();

        // Set and update the parameters as needed for the Rate Registry.
        _setRateRegistryStartingRates();
        _updateRateRegistryRates();

        // Set, update, and assert the parameters as needed for the Group Message Broadcaster and Identity Update
        // Broadcaster.
        _setBroadcasterStartingParameters();
        _bridgeBroadcasterStartingParameters(_appChainId);
        _handleQueuedBridgeEvents();
        _assertBroadcasterStartingParameters();
        _updateBroadcasterStartingParameters();
    }

    /* ============ Factory Helpers ============ */

    function _deployAppChainFactoryImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = FactoryDeployer.deployImplementation(parameterRegistry_);
        vm.stopPrank();

        assertEq(IFactory(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployAppChainFactoryProxy(address implementation_) internal returns (IFactory factory_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = FactoryDeployer.deployProxy(implementation_);
        vm.stopPrank();

        factory_ = IFactory(proxy_);

        // NOTE: The factory implementation may not yet be deployed, so `factory_.implementation()` may revert.
    }

    function _initializeAppChainFactory(address expectedImplementation_) internal {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        _appChainFactory.initialize();
        vm.stopPrank();

        assertEq(_appChainFactory.implementation(), expectedImplementation_);

        assertEq(
            _appChainFactory.initializableImplementation(),
            IFactory(_SETTLEMENT_CHAIN_FACTORY).initializableImplementation()
        );
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deployAppChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(address(_appChainFactory));
        vm.stopPrank();
    }

    function _deployAppChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (IAppChainParameterRegistry registry_) {
        vm.selectFork(_appChainForkId);

        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = AppChainParameterRegistryDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        registry_ = IAppChainParameterRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
        assertTrue(registry_.isAdmin(admin_));
    }

    /* ============ Gateway Helpers ============ */

    function _deploySettlementChainGatewayImplementation(
        address parameterRegistry_,
        address appChainGateway_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
            _SETTLEMENT_CHAIN_FACTORY,
            parameterRegistry_,
            appChainGateway_,
            feeToken_
        );
        vm.stopPrank();

        assertEq(ISettlementChainGateway(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(ISettlementChainGateway(implementation_).appChainGateway(), appChainGateway_);
        assertEq(ISettlementChainGateway(implementation_).feeToken(), feeToken_);
    }

    function _deployAppChainGatewayImplementation(
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
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
            AddressAliasHelper.toAlias(settlementChainGateway_)
        );
    }

    function _deploySettlementChainGatewayProxy(
        address implementation_
    ) internal returns (ISettlementChainGateway gateway_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        gateway_ = ISettlementChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    function _deployAppChainGatewayProxy(address implementation_) internal returns (IAppChainGateway gateway_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = AppChainGatewayDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        gateway_ = IAppChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    function _setInboxParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](1);
        keys_[0] = ParameterKeys.combineKeyComponents(
            _SETTLEMENT_CHAIN_GATEWAY_INBOX_KEY,
            ParameterKeys.uint256ToKeyComponent(_appChainId)
        );

        bytes32[] memory values_ = new bytes32[](1);
        values_[0] = bytes32(uint256(uint160(_SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN)));

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[0]), values_[0]);
    }

    function _updateInboxParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.prank(_ADMIN);
        _settlementChainGatewayProxy.updateInbox(_appChainId);
    }

    /* ============ Group Message Broadcaster Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
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
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _GROUP_MESSAGE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IGroupMessageBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Identity Update Broadcaster Helpers ============ */

    function _deployIdentityUpdateBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
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
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            address(_appChainFactory),
            implementation_,
            _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Broadcaster Helpers ============ */

    function _setBroadcasterStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[1] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);
        values_[2] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[3] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[3]), values_[3]);
    }

    function _bridgeBroadcasterStartingParameters(uint256 chainId_) internal {
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 4);
        uint256 cost_ = (_APP_CHAIN_GAS_PRICE * gasLimit_) / 1e12; // 1e6 / 1e18 = 1 / 1e12

        _giveUnderlyingFeeTokens(_alice, cost_);
        _mintFeeTokens(_alice, cost_);

        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        _approveTokens(_FEE_TOKEN, _alice, address(_settlementChainGatewayProxy), cost_);

        _sendParametersAsRetryableTickets(_alice, chainId_, keys_, gasLimit_, _APP_CHAIN_GAS_PRICE, cost_);
    }

    function _assertBroadcasterStartingParameters() internal {
        vm.selectFork(_appChainForkId);

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

    function _updateBroadcasterStartingParameters() internal {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_alice);
        _groupMessageBroadcasterProxy.updateMaxPayloadSize();
        _groupMessageBroadcasterProxy.updateMinPayloadSize();
        _identityUpdateBroadcasterProxy.updateMaxPayloadSize();
        _identityUpdateBroadcasterProxy.updateMinPayloadSize();
        vm.stopPrank();

        assertEq(_groupMessageBroadcasterProxy.minPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);

        assertEq(_groupMessageBroadcasterProxy.maxPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);

        assertEq(
            _identityUpdateBroadcasterProxy.minPayloadSize(),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            _identityUpdateBroadcasterProxy.maxPayloadSize(),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    /* ============ Payer Registry Helpers ============ */

    function _deployPayerRegistryImplementation(
        address parameterRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(
            _SETTLEMENT_CHAIN_FACTORY,
            parameterRegistry_,
            feeToken_
        );
        vm.stopPrank();

        assertEq(IPayerRegistry(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerRegistry(implementation_).feeToken(), feeToken_);
    }

    function _deployPayerRegistryProxy(address implementation_) internal returns (IPayerRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _PAYER_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IPayerRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setPayerRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](4);
        keys_[0] = _PAYER_REGISTRY_SETTLER_KEY;
        keys_[1] = _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY;
        keys_[2] = _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY;
        keys_[3] = _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(uint256(uint160(address(_payerReportManagerProxy))));
        values_[1] = bytes32(uint256(uint160(address(_distributionManagerProxy))));
        values_[2] = bytes32(_PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        values_[3] = bytes32(_PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[3]), values_[3]);
    }

    function _updatePayerRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_alice);
        _payerRegistryProxy.updateSettler();
        _payerRegistryProxy.updateFeeDistributor();
        _payerRegistryProxy.updateMinimumDeposit();
        _payerRegistryProxy.updateWithdrawLockPeriod();
        vm.stopPrank();

        assertEq(_payerRegistryProxy.settler(), address(_payerReportManagerProxy));
        assertEq(_payerRegistryProxy.feeDistributor(), address(_distributionManagerProxy));
        assertEq(_payerRegistryProxy.minimumDeposit(), _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        assertEq(_payerRegistryProxy.withdrawLockPeriod(), _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);
    }

    /* ============ Rate Registry Helpers ============ */

    function _deployRateRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = RateRegistryDeployer.deployImplementation(_SETTLEMENT_CHAIN_FACTORY, parameterRegistry_);
        vm.stopPrank();

        assertEq(IRateRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployRateRegistryProxy(address implementation_) internal returns (IRateRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = RateRegistryDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _RATE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IRateRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setRateRegistryStartingRates() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](4);
        keys_[0] = _RATE_REGISTRY_MESSAGE_FEE_KEY;
        keys_[1] = _RATE_REGISTRY_STORAGE_FEE_KEY;
        keys_[2] = _RATE_REGISTRY_CONGESTION_FEE_KEY;
        keys_[3] = _RATE_REGISTRY_TARGET_RATE_PER_MINUTE_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(_RATE_REGISTRY_STARTING_MESSAGE_FEE);
        values_[1] = bytes32(_RATE_REGISTRY_STARTING_STORAGE_FEE);
        values_[2] = bytes32(_RATE_REGISTRY_STARTING_CONGESTION_FEE);
        values_[3] = bytes32(_RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[3]), values_[3]);
    }

    function _updateRateRegistryRates() internal {
        vm.selectFork(_settlementChainForkId);

        vm.prank(_alice);
        _rateRegistryProxy.updateRates();

        assertEq(_rateRegistryProxy.getRatesCount(), 1);

        IRateRegistry.Rates[] memory rates_ = _rateRegistryProxy.getRates(0, 1);

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, _RATE_REGISTRY_STARTING_MESSAGE_FEE);
        assertEq(rates_[0].storageFee, _RATE_REGISTRY_STARTING_STORAGE_FEE);
        assertEq(rates_[0].congestionFee, _RATE_REGISTRY_STARTING_CONGESTION_FEE);
        assertEq(rates_[0].targetRatePerMinute, _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE);
        assertEq(rates_[0].startTime, uint64(vm.getBlockTimestamp()));
    }

    /* ============ Node Registry Helpers ============ */

    function _deployNodeRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = NodeRegistryDeployer.deployImplementation(_SETTLEMENT_CHAIN_FACTORY, parameterRegistry_);
        vm.stopPrank();

        assertEq(INodeRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployNodeRegistryProxy(address implementation_) internal returns (INodeRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _NODE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = INodeRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setNodeRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_ADMIN)));
        values_[1] = bytes32(_NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_SETTLEMENT_CHAIN_PARAMETER_REGISTRY).get(keys_[1]), values_[1]);
    }

    function _updateNodeRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_alice);
        _nodeRegistryProxy.updateAdmin();
        _nodeRegistryProxy.updateMaxCanonicalNodes();
        vm.stopPrank();

        assertEq(_nodeRegistryProxy.admin(), _ADMIN);
        assertEq(_nodeRegistryProxy.maxCanonicalNodes(), _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES);
    }

    /* ============ Payer Report Manager Helpers ============ */

    function _deployPayerReportManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
            _SETTLEMENT_CHAIN_FACTORY,
            parameterRegistry_,
            nodeRegistry_,
            payerRegistry_
        );
        vm.stopPrank();

        assertEq(IPayerReportManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerReportManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IPayerReportManager(implementation_).payerRegistry(), payerRegistry_);
    }

    function _deployPayerReportManagerProxy(address implementation_) internal returns (IPayerReportManager registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _PAYER_REPORT_MANAGER_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IPayerReportManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Distribution Manager Helpers ============ */

    function _deployDistributionManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            _SETTLEMENT_CHAIN_FACTORY,
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            feeToken_
        );
        vm.stopPrank();

        assertEq(IDistributionManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IDistributionManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IDistributionManager(implementation_).payerReportManager(), payerReportManager_);
        assertEq(IDistributionManager(implementation_).payerRegistry(), payerRegistry_);
        assertEq(IDistributionManager(implementation_).feeToken(), feeToken_);
    }

    function _deployDistributionManagerProxy(
        address implementation_
    ) internal returns (IDistributionManager registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            _SETTLEMENT_CHAIN_FACTORY,
            implementation_,
            _DISTRIBUTION_MANAGER_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IDistributionManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlyingFeeTokens(address recipient_, uint256 amount_) internal {
        vm.selectFork(_settlementChainForkId);
        MockUnderlyingFeeToken(_UNDERLYING_FEE_TOKEN).mint(recipient_, amount_);
    }

    function _approveTokens(address token_, address account_, address spender_, uint256 amount_) internal {
        vm.selectFork(_settlementChainForkId);
        vm.prank(account_);
        IERC20Like(token_).approve(spender_, amount_);
    }

    function _mintFeeTokens(address account_, uint256 amount_) internal {
        _approveTokens(_UNDERLYING_FEE_TOKEN, account_, _FEE_TOKEN, amount_);

        vm.selectFork(_settlementChainForkId);

        vm.prank(account_);
        IFeeToken(_FEE_TOKEN).deposit(amount_);
    }

    /* ============ Bridge Helpers ============ */

    function _sendParametersAsRetryableTickets(
        address account_,
        uint256 chainId_,
        string[] memory keys_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 amountToSend_
    ) internal {
        _approveTokens(_FEE_TOKEN, account_, address(_settlementChainGatewayProxy), amountToSend_);

        vm.selectFork(_settlementChainForkId);

        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = chainId_;

        vm.prank(account_);
        _settlementChainGatewayProxy.sendParametersAsRetryableTickets(
            chainIds_,
            keys_,
            gasLimit_,
            gasPrice_,
            amountToSend_
        );
    }

    function _handleQueuedBridgeEvents() internal {
        vm.selectFork(_settlementChainForkId);

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
            vm.selectFork(_appChainForkId);
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

        // NOTE: Cannot do this due to `InvalidFEOpcode` error as foundry likely doesn't support `ArbOS` opcodes.
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
        (bool success_, ) = to_.call(data_);
        assertTrue(success_);
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

    /* ============ Expected Address Getters ============ */

    function _expectedGatewayProxy() internal returns (address expectedGatewayProxy_) {
        vm.selectFork(_settlementChainForkId);
        return IFactory(_SETTLEMENT_CHAIN_FACTORY).computeProxyAddress(_DEPLOYER, _GATEWAY_PROXY_SALT);
    }

    /**
     * @dev This address calculation assume the following deployment order:
     *          1. Factory proxy (nonce 0)
     *          2. Factory implementation (nonce 1)
     *      Any deviation from this order will result in incorrect addresses
     */
    function _getExpectedFactoryImplementation() internal view returns (address expectedFactoryImplementation_) {
        return vm.computeCreateAddress(_DEPLOYER, 1);
    }

    /**
     * @dev This address calculation assume the following deployment order:
     *          1. Factory proxy (nonce 0)
     *          2. Factory implementation (nonce 1)
     *      Any deviation from this order will result in incorrect addresses
     */
    function _getExpectedParameterRegistryProxy() internal view returns (address expectedParameterRegistryProxy_) {
        address expectedFactoryProxyAddress_ = vm.computeCreateAddress(_DEPLOYER, 0);
        address expectedFactoryImplementationAddress_ = vm.computeCreateAddress(_DEPLOYER, 1);

        address expectedInitializableImplementation_ = vm.computeCreateAddress(
            expectedFactoryImplementationAddress_,
            1
        );

        bytes memory initCode_ = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(expectedInitializableImplementation_)
        );

        return
            vm.computeCreate2Address(
                keccak256(abi.encode(_DEPLOYER, _PARAMETER_REGISTRY_PROXY_SALT)),
                keccak256(initCode_),
                expectedFactoryProxyAddress_
            );
    }
}
