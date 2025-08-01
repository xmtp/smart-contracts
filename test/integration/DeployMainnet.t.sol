// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Test.sol";

import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import { FeeTokenDeployer } from "../../script/deployers/FeeTokenDeployer.sol";

import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";

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

        _distributionManagerProxySalt = "DistributionManager_0";
        _groupMessageBroadcasterProxySalt = "GroupMessageBroadcaster_0";
        _identityUpdateBroadcasterProxySalt = "IdentityUpdateBroadcaster_0";
        _nodeRegistryProxySalt = "NodeRegistry_0";
        _payerRegistryProxySalt = "PayerRegistry_0";
        _payerReportManagerProxySalt = "PayerReportManager_0";
        _rateRegistryProxySalt = "RateRegistry_0";

        _factory = 0x9492Ea65F5f20B01Ed5eBe1b49f77208123585a1;
        _feeToken = 0x63C6667798fdA65E2E29228C43fbfDa0Cd4634A8;
        _gateway = 0xB64D5bF62F30512Bd130C0D7c80DB7ac1e6801a3;
        _parameterRegistry = 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D;
        _underlyingFeeToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base Mainnet.

        _settlementChainForkId = vm.createSelectFork("base_mainnet");
        _settlementChainId = block.chainid;
    }

    function test_deployMainnetProtocol() external {
        // Deploy the Payer Registry on the settlement chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(_parameterRegistry, _feeToken);

        console.log("payerRegistryImplementation: %s", address(payerRegistryImplementation_));

        _payerRegistry = _deployPayerRegistryProxy(payerRegistryImplementation_);

        console.log("payerRegistryProxy: %s", address(_payerRegistry));

        // Deploy the Rate Registry on the settlement chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(_parameterRegistry);

        console.log("rateRegistryImplementation: %s", address(rateRegistryImplementation_));

        _rateRegistry = _deployRateRegistryProxy(rateRegistryImplementation_);

        console.log("rateRegistryProxy: %s", address(_rateRegistry));

        // Deploy the Node Registry on the settlement chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(_parameterRegistry);

        console.log("nodeRegistryImplementation: %s", address(nodeRegistryImplementation_));

        _nodeRegistry = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        console.log("nodeRegistryProxy: %s", address(_nodeRegistry));

        // Deploy the Payer Report Manager on the settlement chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            _parameterRegistry,
            address(_nodeRegistry),
            address(_payerRegistry)
        );

        console.log("payerReportManagerImplementation: %s", address(payerReportManagerImplementation_));

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

        console.log("distributionManagerImplementation: %s", address(distributionManagerImplementation_));

        _distributionManager = _deployDistributionManagerProxy(distributionManagerImplementation_);

        console.log("distributionManagerProxy: %s", address(_distributionManager));

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
    }

    function _deployBaseSettlementChainComponents() internal {
        vm.startPrank(_DEPLOYER);
        (_factory, , ) = FactoryDeployer.deployProxy(_getExpectedFactoryImplementation());
        vm.stopPrank();

        console.log("Factory Proxy: %s", _factory);

        address expectedParameterRegistryProxy_ = _getExpectedParameterRegistryProxy();

        vm.startPrank(_DEPLOYER);
        (address factoryImplementation_, ) = FactoryDeployer.deployImplementation(expectedParameterRegistryProxy_);
        vm.stopPrank();

        console.log("Factory Implementation: %s", factoryImplementation_);

        vm.startPrank(_DEPLOYER);
        IFactory(_factory).initialize();
        vm.stopPrank();

        console.log("Initializable Implementation: %s", IFactory(_factory).initializableImplementation());

        vm.startPrank(_DEPLOYER);
        (address settlementChainParameterRegistryImplementation_, ) = SettlementChainParameterRegistryDeployer
            .deployImplementation(_factory);
        vm.stopPrank();

        console.log(
            "Settlement Chain Parameter Registry Implementation: %s",
            settlementChainParameterRegistryImplementation_
        );

        address[] memory admins_ = new address[](1);
        admins_[0] = _ADMIN;

        vm.startPrank(_DEPLOYER);
        (_parameterRegistry, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            _factory,
            settlementChainParameterRegistryImplementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        console.log("Settlement Chain Parameter Registry Proxy: %s", _parameterRegistry);

        vm.startPrank(_DEPLOYER);
        (address feeTokenImplementation_, ) = FeeTokenDeployer.deployImplementation(
            _factory,
            _parameterRegistry,
            _underlyingFeeToken
        );
        vm.stopPrank();

        console.log("Fee Token Implementation: %s", feeTokenImplementation_);

        vm.startPrank(_DEPLOYER);
        (_feeToken, , ) = FeeTokenDeployer.deployProxy(_factory, feeTokenImplementation_, _FEE_TOKEN_PROXY_SALT);
        vm.stopPrank();

        console.log("Fee Token Proxy: %s", _feeToken);

        vm.startPrank(_DEPLOYER);
        (address settlementChainGatewayImplementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
            _factory,
            _parameterRegistry,
            _gateway,
            _feeToken
        );
        vm.stopPrank();

        console.log("Settlement Chain Gateway Implementation: %s", settlementChainGatewayImplementation_);

        vm.startPrank(_DEPLOYER);
        (_gateway, , ) = SettlementChainGatewayDeployer.deployProxy(
            _factory,
            settlementChainGatewayImplementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        console.log("Settlement Chain Gateway Proxy: %s", _gateway);
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
