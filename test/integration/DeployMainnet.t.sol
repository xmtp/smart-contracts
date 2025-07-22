// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Test.sol";

import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import { FeeTokenDeployer } from "../../script/deployers/FeeTokenDeployer.sol";

import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

/* ============ Test Contract Imports ============ */

import { DeployTests } from "./Deploy.sol";

contract DeployMainnetTests is DeployTests {
    function setUp() public override {
        super.setUp();

        _underlyingFeeToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base.

        _distributionManagerProxySalt = "DistributionManager_0";
        _gatewayProxySalt = "Gateway_0";
        _groupMessageBroadcasterProxySalt = "GroupMessageBroadcaster_0";
        _identityUpdateBroadcasterProxySalt = "IdentityUpdateBroadcaster_0";
        _nodeRegistryProxySalt = "NodeRegistry_0";
        _payerRegistryProxySalt = "PayerRegistry_0";
        _payerReportManagerProxySalt = "PayerReportManager_0";
        _rateRegistryProxySalt = "RateRegistry_0";

        _factoryProxy = 0x9492Ea65F5f20B01Ed5eBe1b49f77208123585a1;
        _parameterRegistryProxy = 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D;
        _feeTokenProxy = 0x63C6667798fdA65E2E29228C43fbfDa0Cd4634A8;

        _settlementChainForkId = vm.createSelectFork("base_mainnet");
        _settlementChainId = block.chainid;
    }

    function test_deployMainnetProtocol() external {
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

        // // Deploy the Gateway on the app chain.
        // address appChainGatewayImplementation_ = _deployAppChainGatewayImplementation(
        //     _parameterRegistryProxy,
        //     address(_settlementChainGatewayProxy)
        // );

        // console.log("appChainGatewayImplementation: %s", address(appChainGatewayImplementation_));

        // _appChainGatewayProxy = _deployAppChainGatewayProxy(appChainGatewayImplementation_);

        // console.log("appChainGatewayProxy: %s", address(_appChainGatewayProxy));

        // // Deploy the Group Message Broadcaster on the app chain.
        // address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
        //     _parameterRegistryProxy
        // );

        // console.log("groupMessageBroadcasterImplementation: %s", address(groupMessageBroadcasterImplementation_));

        // _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        // console.log("groupMessageBroadcasterProxy: %s", address(_groupMessageBroadcasterProxy));

        // // Deploy the Identity Update Broadcaster on the app chain.
        // address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
        //     _parameterRegistryProxy
        // );

        // console.log("identityUpdateBroadcasterImplementation: %s", address(identityUpdateBroadcasterImplementation_));

        // _identityUpdateBroadcasterProxy = _deployIdentityUpdateBroadcasterProxy(
        //     identityUpdateBroadcasterImplementation_
        // );

        // console.log("identityUpdateBroadcasterProxy: %s", address(_identityUpdateBroadcasterProxy));

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
        // _bridgeBroadcasterStartingParameters(_appChainId);
        // _handleQueuedBridgeEvents();
        // _assertBroadcasterStartingParameters();
        // _updateBroadcasterStartingParameters();
    }

    function _deployBaseSettlementChainComponents() internal {
        vm.startPrank(_DEPLOYER);
        (_factoryProxy, , ) = FactoryDeployer.deployProxy(_getExpectedFactoryImplementation());
        vm.stopPrank();

        console.log("Factory Proxy: %s", _factoryProxy);

        address expectedParameterRegistryProxy_ = _getExpectedParameterRegistryProxy();

        vm.startPrank(_DEPLOYER);
        (address factoryImplementation_, ) = FactoryDeployer.deployImplementation(expectedParameterRegistryProxy_);
        vm.stopPrank();

        console.log("Factory Implementation: %s", factoryImplementation_);

        vm.startPrank(_DEPLOYER);
        IFactory(_factoryProxy).initialize();
        vm.stopPrank();

        console.log("Initializable Implementation: %s", IFactory(_factoryProxy).initializableImplementation());

        vm.startPrank(_DEPLOYER);
        (address settlementChainParameterRegistryImplementation_, ) = SettlementChainParameterRegistryDeployer
            .deployImplementation(_factoryProxy);
        vm.stopPrank();

        console.log(
            "Settlement Chain Parameter Registry Implementation: %s",
            settlementChainParameterRegistryImplementation_
        );

        address[] memory admins_ = new address[](1);
        admins_[0] = _ADMIN;

        vm.startPrank(_DEPLOYER);
        (_parameterRegistryProxy, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            _factoryProxy,
            settlementChainParameterRegistryImplementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        console.log("Settlement Chain Parameter Registry Proxy: %s", _parameterRegistryProxy);

        vm.startPrank(_DEPLOYER);
        (address feeTokenImplementation_, ) = FeeTokenDeployer.deployImplementation(
            _factoryProxy,
            _parameterRegistryProxy,
            _underlyingFeeToken
        );
        vm.stopPrank();

        console.log("Fee Token Implementation: %s", feeTokenImplementation_);

        vm.startPrank(_DEPLOYER);
        (_feeTokenProxy, , ) = FeeTokenDeployer.deployProxy(
            _factoryProxy,
            feeTokenImplementation_,
            _FEE_TOKEN_PROXY_SALT
        );
        vm.stopPrank();

        console.log("Fee Token Proxy: %s", _feeTokenProxy);
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlyingFeeTokens(address recipient_, uint256 amount_) internal override {
        vm.selectFork(_settlementChainForkId);
        deal(_underlyingFeeToken, recipient_, amount_);
    }

    /* ============ Expected Address Getters ============ */

    function _getExpectedFactoryImplementation() internal view returns (address expectedFactoryImplementation_) {
        return vm.computeCreateAddress(_DEPLOYER, 1);
    }

    function _getExpectedParameterRegistryProxy() internal view returns (address expectedParameterRegistryProxy_) {
        address expectedFactoryProxyAddress_ = vm.computeCreateAddress(_DEPLOYER, 0);
        address expectedInitializableImplementation_ = vm.computeCreateAddress(expectedFactoryProxyAddress_, 1);

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
