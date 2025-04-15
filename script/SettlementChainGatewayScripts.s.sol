// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { SettlementChainGatewayDeployer } from "./deployers/SettlementChainGatewayDeployer.sol";

import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract SettlementChainGatewayScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error GatewayProxyNotSet();
    error AppChainNativeTokenNotSet();
    error GatewayProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.settlementChainGatewayImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.gatewayProxy != address(0), GatewayProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = SettlementChainGatewayDeployer
            .deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.gatewayProxy,
                _deploymentData.appChainNativeToken
            );

        require(implementation_ == _deploymentData.settlementChainGatewayImplementation, UnexpectedImplementation());

        require(
            ISettlementChainGateway(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            ISettlementChainGateway(implementation_).appChainGateway() == _deploymentData.gatewayProxy,
            UnexpectedImplementation()
        );

        require(
            ISettlementChainGateway(implementation_).appChainNativeToken() == _deploymentData.appChainNativeToken,
            UnexpectedImplementation()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            _deploymentData.factory,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(Utils.SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.gatewayProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.settlementChainGatewayImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.gatewayProxySalt != bytes32(0), GatewayProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = SettlementChainGatewayDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.settlementChainGatewayImplementation,
            _deploymentData.gatewayProxySalt
        );

        require(proxy_ == _deploymentData.gatewayProxy, UnexpectedProxy());

        require(
            ISettlementChainGateway(proxy_).implementation() == _deploymentData.settlementChainGatewayImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.gatewayProxy != address(0), GatewayProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        address implementation_ = SettlementChainGatewayDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy,
            _deploymentData.appChainNativeToken
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.gatewayProxySalt != bytes32(0), GatewayProxySaltNotSet());

        address proxy_ = SettlementChainGatewayDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.gatewayProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
