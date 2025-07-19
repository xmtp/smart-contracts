// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Test.sol";

/* ============ Test Contract Imports ============ */

import { MockUnderlyingFeeToken } from "../utils/Mocks.sol";
import { DeployTests } from "./Deploy.sol";

contract DeployTestnetTests is DeployTests {
    bytes32 internal constant _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT = "MockUnderlyingFeeToken_0";

    function setUp() public override {
        super.setUp();

        _settlementChainInboxToAppchain = 0xA382f402Cb702484B424AC8e2B7fEE9B032C6b9d;
        _settlementChainBridge = 0xD05baD3cec5E67152178F731aae8025fC1F2DAEA;

        _feeTokenProxy = 0x63C6667798fdA65E2E29228C43fbfDa0Cd4634A8;
        _factoryProxy = 0x9492Ea65F5f20B01Ed5eBe1b49f77208123585a1;
        _parameterRegistryProxy = 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D;
        _underlyingFeeToken = 0x2d7e0534183dAD09008C97f230d9F4f6425eE859;

        _appChainGasPrice = 2_000_000_000; // 2 gwei per gas.

        _distributionManagerProxySalt = "DistributionManager_0_0";
        _gatewayProxySalt = "Gateway_0_0";
        _groupMessageBroadcasterProxySalt = "GroupMessageBroadcaster_0_0";
        _identityUpdateBroadcasterProxySalt = "IdentityUpdateBroadcaster_0_0";
        _nodeRegistryProxySalt = "NodeRegistry_0_0";
        _payerRegistryProxySalt = "PayerRegistry_0_0";
        _payerReportManagerProxySalt = "PayerReportManager_0_0";
        _rateRegistryProxySalt = "RateRegistry_0_0";

        _settlementChainForkId = vm.createSelectFork("base_sepolia");
        _settlementChainId = block.chainid;

        _appChainForkId = vm.createSelectFork("xmtp_ropsten");
        _appChainId = block.chainid;
    }

    function test_deployTestnetProtocol() external {
        vm.skip(true);

        // Get the expected address of the Gateway on the app chain, since the Parameter Registry on the
        // same chain will need it.
        address expectedGatewayProxy_ = _expectedGatewayProxy();

        // Deploy the Gateway on the settlement chain.
        address settlementChainGatewayImplementation_ = _deploySettlementChainGatewayImplementation(
            _parameterRegistryProxy,
            expectedGatewayProxy_,
            _feeTokenProxy
        );

        console.log("settlementChainGatewayImplementation: %s", address(settlementChainGatewayImplementation_));

        _settlementChainGatewayProxy = _deploySettlementChainGatewayProxy(settlementChainGatewayImplementation_);

        console.log("settlementChainGatewayProxy: %s", address(_settlementChainGatewayProxy));

        // Deploy the Payer Registry on the settlement chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(
            _parameterRegistryProxy,
            _feeTokenProxy
        );

        console.log("payerRegistryImplementation: %s", address(payerRegistryImplementation_));

        _payerRegistryProxy = _deployPayerRegistryProxy(payerRegistryImplementation_);

        console.log("payerRegistryProxy: %s", address(_payerRegistryProxy));

        // Deploy the Rate Registry on the settlement chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(_parameterRegistryProxy);

        console.log("rateRegistryImplementation: %s", address(rateRegistryImplementation_));

        _rateRegistryProxy = _deployRateRegistryProxy(rateRegistryImplementation_);

        console.log("rateRegistryProxy: %s", address(_rateRegistryProxy));

        // Deploy the Node Registry on the settlement chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(_parameterRegistryProxy);

        console.log("nodeRegistryImplementation: %s", address(nodeRegistryImplementation_));

        _nodeRegistryProxy = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        console.log("nodeRegistryProxy: %s", address(_nodeRegistryProxy));

        // Deploy the Payer Report Manager on the settlement chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            _parameterRegistryProxy,
            address(_nodeRegistryProxy),
            address(_payerRegistryProxy)
        );

        console.log("payerReportManagerImplementation: %s", address(payerReportManagerImplementation_));

        _payerReportManagerProxy = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        console.log("payerReportManagerProxy: %s", address(_payerReportManagerProxy));

        // Deploy the Distribution Manager on the settlement chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            _parameterRegistryProxy,
            address(_nodeRegistryProxy),
            address(_payerReportManagerProxy),
            address(_payerRegistryProxy),
            _feeTokenProxy
        );

        console.log("distributionManagerImplementation: %s", address(distributionManagerImplementation_));

        _distributionManagerProxy = _deployDistributionManagerProxy(distributionManagerImplementation_);

        console.log("distributionManagerProxy: %s", address(_distributionManagerProxy));

        // Deploy the Gateway on the app chain.
        address appChainGatewayImplementation_ = _deployAppChainGatewayImplementation(
            _parameterRegistryProxy,
            address(_settlementChainGatewayProxy)
        );

        console.log("appChainGatewayImplementation: %s", address(appChainGatewayImplementation_));

        _appChainGatewayProxy = _deployAppChainGatewayProxy(appChainGatewayImplementation_);

        console.log("appChainGatewayProxy: %s", address(_appChainGatewayProxy));

        // Deploy the Group Message Broadcaster on the app chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            _parameterRegistryProxy
        );

        console.log("groupMessageBroadcasterImplementation: %s", address(groupMessageBroadcasterImplementation_));

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        console.log("groupMessageBroadcasterProxy: %s", address(_groupMessageBroadcasterProxy));

        // Deploy the Identity Update Broadcaster on the app chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            _parameterRegistryProxy
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

        // Set and update the parameters as needed for the Payer Report Manager.
        _setPayerReportManagerStartingParameters();
        _updatePayerReportManagerStartingParameters();

        // Set, update, and assert the parameters as needed for the Group Message Broadcaster and Identity Update
        // Broadcaster.
        _setBroadcasterStartingParameters();
        _bridgeBroadcasterStartingParameters(_appChainId);
        _handleQueuedBridgeEvents();
        _assertBroadcasterStartingParameters();
        _updateBroadcasterStartingParameters();
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlyingFeeTokens(address recipient_, uint256 amount_) internal override {
        vm.selectFork(_settlementChainForkId);
        MockUnderlyingFeeToken(_underlyingFeeToken).mint(recipient_, amount_);
    }
}
