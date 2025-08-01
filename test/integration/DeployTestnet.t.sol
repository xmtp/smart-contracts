// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Test.sol";

/* ============ Source Interface Imports ============ */

import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
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

/* ============ Test Contract Imports ============ */

import { MockUnderlyingFeeToken } from "../utils/Mocks.sol";
import { DeployTests } from "./Deploy.sol";

contract DeployTestnetTests is DeployTests {
    bytes32 internal constant _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT = "MockUnderlyingFeeToken_0";

    function setUp() public override {
        super.setUp();

        _settlementChainInboxToAppchain = 0xA382f402Cb702484B424AC8e2B7fEE9B032C6b9d;
        _settlementChainBridge = 0xD05baD3cec5E67152178F731aae8025fC1F2DAEA;

        _factory = 0x9492Ea65F5f20B01Ed5eBe1b49f77208123585a1;
        _feeToken = 0x63C6667798fdA65E2E29228C43fbfDa0Cd4634A8;
        _gateway = 0xB64D5bF62F30512Bd130C0D7c80DB7ac1e6801a3;
        _parameterRegistry = 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D;
        _underlyingFeeToken = 0x2d7e0534183dAD09008C97f230d9F4f6425eE859; // Mock Underlying Fee Token on Base Ropsten.

        _appChainGasPrice = 2_000_000_000; // 2 gwei per gas.

        _distributionManagerProxySalt = "DistributionManager_1_0";
        _groupMessageBroadcasterProxySalt = "GroupMessageBroadcaster_1_0";
        _identityUpdateBroadcasterProxySalt = "IdentityUpdateBroadcaster_1_0";
        _nodeRegistryProxySalt = "NodeRegistry_1_0";
        _payerRegistryProxySalt = "PayerRegistry_1_0";
        _payerReportManagerProxySalt = "PayerReportManager_1_0";
        _rateRegistryProxySalt = "RateRegistry_1_0";

        _settlementChainForkId = vm.createSelectFork("base_sepolia");
        _settlementChainId = block.chainid;

        _appChainForkId = vm.createSelectFork("xmtp_ropsten");
        _appChainId = block.chainid;
    }

    function test_deployTestnetProtocol() external {
        vm.skip(true);

        // Deploy the Payer Registry on the settlement chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(_parameterRegistry, _feeToken);

        console.log("payerRegistryImplementation: %s", payerRegistryImplementation_);

        _payerRegistry = _deployPayerRegistryProxy(payerRegistryImplementation_);

        console.log("payerRegistryProxy: %s", address(_payerRegistry));

        // Deploy the Rate Registry on the settlement chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(_parameterRegistry);

        console.log("rateRegistryImplementation: %s", rateRegistryImplementation_);

        _rateRegistry = _deployRateRegistryProxy(rateRegistryImplementation_);

        console.log("rateRegistryProxy: %s", address(_rateRegistry));

        // Deploy the Node Registry on the settlement chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(_parameterRegistry);

        console.log("nodeRegistryImplementation: %s", nodeRegistryImplementation_);

        _nodeRegistry = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        console.log("nodeRegistryProxy: %s", address(_nodeRegistry));

        // Deploy the Payer Report Manager on the settlement chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            _parameterRegistry,
            address(_nodeRegistry),
            address(_payerRegistry)
        );

        console.log("payerReportManagerImplementation: %s", payerReportManagerImplementation_);

        _payerReportManager = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        console.log("payerReportManagerProxy: %s", address(_payerReportManager));

        // Deploy the Distribution Manager on the settlement chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            _parameterRegistry,
            address(_nodeRegistry),
            address(_payerReportManager),
            address(_payerRegistry),
            _feeToken
        );

        console.log("distributionManagerImplementation: %s", distributionManagerImplementation_);

        _distributionManager = _deployDistributionManagerProxy(distributionManagerImplementation_);

        console.log("distributionManagerProxy: %s", address(_distributionManager));

        // Deploy the Deposit Splitter on the settlement chain.
        _depositSplitter = _deployDepositSplitter(_feeToken, address(_payerRegistry), _gateway, _appChainId);

        console.log("depositSplitter: %s", address(_depositSplitter));

        // Deploy the Group Message Broadcaster on the app chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            _parameterRegistry
        );

        console.log("groupMessageBroadcasterImplementation: %s", groupMessageBroadcasterImplementation_);

        _groupMessageBroadcaster = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        console.log("groupMessageBroadcasterProxy: %s", address(_groupMessageBroadcaster));

        // Deploy the Identity Update Broadcaster on the app chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            _parameterRegistry
        );

        console.log("identityUpdateBroadcasterImplementation: %s", identityUpdateBroadcasterImplementation_);

        _identityUpdateBroadcaster = _deployIdentityUpdateBroadcasterProxy(identityUpdateBroadcasterImplementation_);

        console.log("identityUpdateBroadcasterProxy: %s", address(_identityUpdateBroadcaster));

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

        // Set and update the parameters as needed for the Payer Report Manager.
        _setPayerReportManagerStartingParameters();
        _updatePayerReportManagerStartingParameters();

        // Set, update, and assert the parameters as needed for the Group Message Broadcaster and Identity Update
        // Broadcaster.
        _setBroadcasterStartingParameters();
        _bridgeBroadcasterStartingParameters(_appChainId, _appChainGasPrice);
        _handleQueuedBridgeEvents();
        _assertBroadcasterStartingParameters();
        _updateBroadcasterStartingParameters();
    }

    function test_migrateTestnetProtocol() external {
        _distributionManager = IDistributionManager(0xbA6bE286C79C4d08f789F5491C894FAd358A31F0);
        _groupMessageBroadcaster = IGroupMessageBroadcaster(0xbDF24fD4bBaE0E3CCd42Fb6C07EC6eA347A1Ef87);
        _identityUpdateBroadcaster = IIdentityUpdateBroadcaster(0x559c8c08A251Cc917ccCde13Caf273156d0c8f35);
        _nodeRegistry = INodeRegistry(0xBC7fc04570397c4170D2dCe4927aa6395f3dED4A);
        _payerRegistry = IPayerRegistry(0x77a9129Cb584DF076a64A995dDEF9158d589D80c);
        _payerReportManager = IPayerReportManager(0x4E514aBB2560CbF85C607f5FD0C51aE7cE2E5b9A);
        _rateRegistry = IRateRegistry(0x89C6Aa3e03224F43290823471E8ed725C35bAcCE);

        // Deploy the Factory implementation on the settlement chain.
        address settlementChainFactoryImplementation_ = _deploySettlementChainFactoryImplementation(_parameterRegistry);

        console.log("settlementChainFactoryImplementation: %s", settlementChainFactoryImplementation_);

        // Try to migrate the Factory on the settlement chain.
        address settlementChainFactoryMigrator_ = _deploySettlementChainMigrator(
            _factory,
            settlementChainFactoryImplementation_
        );

        console.log("settlementChainFactoryMigrator: %s", settlementChainFactoryMigrator_);

        _migrateOnSettlementChain(_factory, settlementChainFactoryMigrator_);

        // Deploy the Parameter Registry implementation on the settlement chain.
        address settlementChainParameterRegistryImplementation_ = _deploySettlementChainParameterRegistryImplementation();

        console.log(
            "settlementChainParameterRegistryImplementation: %s",
            address(settlementChainParameterRegistryImplementation_)
        );

        // Try to migrate the Parameter Registry on the settlement chain.
        address settlementChainParameterRegistryMigrator_ = _deploySettlementChainMigrator(
            _parameterRegistry,
            settlementChainParameterRegistryImplementation_
        );

        console.log("settlementChainParameterRegistryMigrator: %s", settlementChainParameterRegistryMigrator_);

        _migrateOnSettlementChain(_parameterRegistry, settlementChainParameterRegistryMigrator_);

        // Deploy the Mock Underlying Fee Token implementation on the settlement chain.
        address mockUnderlyingFeeTokenImplementation_ = _deployMockUnderlyingFeeTokenImplementation(_parameterRegistry);

        console.log("mockUnderlyingFeeTokenImplementation: %s", mockUnderlyingFeeTokenImplementation_);

        // Try to migrate the Mock Underlying Fee Token on the settlement chain.
        address mockUnderlyingFeeTokenMigrator_ = _deploySettlementChainMigrator(
            _underlyingFeeToken,
            mockUnderlyingFeeTokenImplementation_
        );

        console.log("mockUnderlyingFeeTokenMigrator: %s", mockUnderlyingFeeTokenMigrator_);

        _migrateOnSettlementChain(_underlyingFeeToken, mockUnderlyingFeeTokenMigrator_);

        // Deploy the Fee Token implementation on the settlement chain.
        address feeTokenImplementation_ = _deployFeeTokenImplementation(_parameterRegistry, _underlyingFeeToken);

        console.log("feeTokenImplementation: %s", feeTokenImplementation_);

        // Try to migrate the Fee Token on the settlement chain.
        address feeTokenMigrator_ = _deploySettlementChainMigrator(_feeToken, feeTokenImplementation_);

        console.log("feeTokenMigrator: %s", feeTokenMigrator_);

        _migrateOnSettlementChain(_feeToken, feeTokenMigrator_);

        // Deploy the Gateway implementation on the settlement chain.
        address settlementChainGatewayImplementation_ = _deploySettlementChainGatewayImplementation(
            _parameterRegistry,
            _expectedGatewayProxy(),
            _feeToken
        );

        console.log("settlementChainGatewayImplementation: %s", settlementChainGatewayImplementation_);

        // Try to migrate the Gateway on the settlement chain.
        address settlementChainGatewayMigrator_ = _deploySettlementChainMigrator(
            _gateway,
            settlementChainGatewayImplementation_
        );

        console.log("settlementChainGatewayMigrator: %s", settlementChainGatewayMigrator_);

        _migrateOnSettlementChain(_gateway, settlementChainGatewayMigrator_);

        // Deploy the Payer Registry on the settlement chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(_parameterRegistry, _feeToken);

        console.log("payerRegistryImplementation: %s", payerRegistryImplementation_);

        // Try to migrate the Payer Registry on the settlement chain.
        address payerRegistryMigrator_ = _deploySettlementChainMigrator(
            address(_payerRegistry),
            payerRegistryImplementation_
        );

        console.log("payerRegistryMigrator: %s", payerRegistryMigrator_);

        _migrateOnSettlementChain(address(_payerRegistry), payerRegistryMigrator_);

        // Deploy the Rate Registry on the settlement chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(_parameterRegistry);

        console.log("rateRegistryImplementation: %s", rateRegistryImplementation_);

        // Try to migrate the Rate Registry on the settlement chain.
        address rateRegistryMigrator_ = _deploySettlementChainMigrator(
            address(_rateRegistry),
            rateRegistryImplementation_
        );

        console.log("rateRegistryMigrator: %s", rateRegistryMigrator_);

        _migrateOnSettlementChain(address(_rateRegistry), rateRegistryMigrator_);

        // Deploy the Node Registry on the settlement chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(_parameterRegistry);

        console.log("nodeRegistryImplementation: %s", nodeRegistryImplementation_);

        // Try to migrate the Node Registry on the settlement chain.
        address nodeRegistryMigrator_ = _deploySettlementChainMigrator(
            address(_nodeRegistry),
            nodeRegistryImplementation_
        );

        console.log("nodeRegistryMigrator: %s", nodeRegistryMigrator_);

        _migrateOnSettlementChain(address(_nodeRegistry), nodeRegistryMigrator_);

        // Deploy the Payer Report Manager on the settlement chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            _parameterRegistry,
            address(_nodeRegistry),
            address(_payerRegistry)
        );

        console.log("payerReportManagerImplementation: %s", payerReportManagerImplementation_);

        // Try to migrate the Payer Report Manager on the settlement chain.
        address payerReportManagerMigrator_ = _deploySettlementChainMigrator(
            address(_payerReportManager),
            payerReportManagerImplementation_
        );

        console.log("payerReportManagerMigrator: %s", payerReportManagerMigrator_);

        _migrateOnSettlementChain(address(_payerReportManager), payerReportManagerMigrator_);

        // Deploy the Distribution Manager on the settlement chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            _parameterRegistry,
            address(_nodeRegistry),
            address(_payerReportManager),
            address(_payerRegistry),
            _feeToken
        );

        console.log("distributionManagerImplementation: %s", distributionManagerImplementation_);

        // Try to migrate the Distribution Manager on the settlement chain.
        address distributionManagerMigrator_ = _deploySettlementChainMigrator(
            address(_distributionManager),
            distributionManagerImplementation_
        );

        console.log("distributionManagerMigrator: %s", distributionManagerMigrator_);

        _migrateOnSettlementChain(address(_distributionManager), distributionManagerMigrator_);

        // Deploy the Deposit Splitter on the settlement chain.
        _depositSplitter = _deployDepositSplitter(_feeToken, address(_payerRegistry), _gateway, _appChainId);

        console.log("depositSplitter: %s", address(_depositSplitter));

        // Deploy the Factory implementation on the app chain.
        address appChainFactoryImplementation_ = _deployAppChainFactoryImplementation(_parameterRegistry);

        console.log("appChainFactoryImplementation: %s", appChainFactoryImplementation_);

        // Try to migrate the Factory on the app chain.
        address appChainFactoryMigrator_ = _deployAppChainMigrator(_factory, appChainFactoryImplementation_);

        console.log("appChainFactoryMigrator: %s", appChainFactoryMigrator_);

        _migrateOnAppChain(_factory, appChainFactoryMigrator_);

        // Deploy the Parameter Registry implementation on the app chain.
        address appChainParameterRegistryImplementation_ = _deployAppChainParameterRegistryImplementation();

        console.log("appChainParameterRegistryImplementation: %s", appChainParameterRegistryImplementation_);

        // Try to migrate the Parameter Registry on the app chain.
        address appChainParameterRegistryMigrator_ = _deployAppChainMigrator(
            _parameterRegistry,
            appChainParameterRegistryImplementation_
        );

        console.log("appChainParameterRegistryMigrator: %s", appChainParameterRegistryMigrator_);

        _migrateOnAppChain(_parameterRegistry, appChainParameterRegistryMigrator_);

        // Deploy the Gateway on the app chain.
        address appChainGatewayImplementation_ = _deployAppChainGatewayImplementation(_parameterRegistry, _gateway);

        console.log("appChainGatewayImplementation: %s", appChainGatewayImplementation_);

        // Try to migrate the Gateway on the app chain.
        address appChainGatewayMigrator_ = _deployAppChainMigrator(_gateway, appChainGatewayImplementation_);

        console.log("appChainGatewayMigrator: %s", appChainGatewayMigrator_);

        _migrateOnAppChain(_gateway, appChainGatewayMigrator_);

        // Deploy the Group Message Broadcaster on the app chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            _parameterRegistry
        );

        console.log("groupMessageBroadcasterImplementation: %s", groupMessageBroadcasterImplementation_);

        // Try to migrate the Group Message Broadcaster on the app chain.
        address groupMessageBroadcasterMigrator_ = _deployAppChainMigrator(
            address(_groupMessageBroadcaster),
            groupMessageBroadcasterImplementation_
        );

        console.log("groupMessageBroadcasterMigrator: %s", groupMessageBroadcasterMigrator_);

        _migrateOnAppChain(address(_groupMessageBroadcaster), groupMessageBroadcasterMigrator_);

        // Deploy the Identity Update Broadcaster on the app chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            _parameterRegistry
        );

        console.log("identityUpdateBroadcasterImplementation: %s", identityUpdateBroadcasterImplementation_);

        // Try to migrate the Identity Update Broadcaster on the app chain.
        address identityUpdateBroadcasterMigrator_ = _deployAppChainMigrator(
            address(_identityUpdateBroadcaster),
            identityUpdateBroadcasterImplementation_
        );

        console.log("identityUpdateBroadcasterMigrator: %s", identityUpdateBroadcasterMigrator_);

        _migrateOnAppChain(address(_identityUpdateBroadcaster), identityUpdateBroadcasterMigrator_);
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlyingFeeTokens(address recipient_, uint256 amount_) internal override {
        vm.selectFork(_settlementChainForkId);
        MockUnderlyingFeeToken(_underlyingFeeToken).mint(recipient_, amount_);
    }
}
