// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { AppChainGatewayDeployer } from "./deployers/AppChainGatewayDeployer.sol";

import { IAppChainGateway } from "../src/app-chain/interfaces/IAppChainGateway.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract AppChainGatewayScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error GatewayProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.appChainGatewayImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.gatewayProxy != address(0), GatewayProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = AppChainGatewayDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy
        );

        require(implementation_ == _deploymentData.appChainGatewayImplementation, UnexpectedImplementation());

        require(
            IAppChainGateway(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IAppChainGateway(implementation_).settlementChainGateway() == _deploymentData.gatewayProxy,
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
            string.concat(Utils.APP_CHAIN_GATEWAY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.gatewayProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.appChainGatewayImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.gatewayProxySalt != bytes32(0), ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = AppChainGatewayDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.appChainGatewayImplementation,
            _deploymentData.gatewayProxySalt
        );

        require(proxy_ == _deploymentData.gatewayProxy, UnexpectedProxy());

        require(
            IAppChainGateway(proxy_).implementation() == _deploymentData.appChainGatewayImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.APP_CHAIN_GATEWAY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.gatewayProxy != address(0), GatewayProxyNotSet());

        address implementation_ = AppChainGatewayDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.gatewayProxySalt != bytes32(0), ProxySaltNotSet());

        address proxy_ = AppChainGatewayDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.gatewayProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
