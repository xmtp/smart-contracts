// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { PayerRegistryDeployer } from "./deployers/PayerRegistryDeployer.sol";

import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract PayerRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error AppChainNativeTokenNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.payerRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = PayerRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.appChainNativeToken
        );

        require(implementation_ == _deploymentData.payerRegistryImplementation, UnexpectedImplementation());

        require(
            IPayerRegistry(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IPayerRegistry(implementation_).token() == _deploymentData.appChainNativeToken,
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
            string.concat(Utils.PAYER_REGISTRY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.payerRegistryProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.payerRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.payerRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = PayerRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.payerRegistryImplementation,
            _deploymentData.payerRegistryProxySalt
        );

        require(proxy_ == _deploymentData.payerRegistryProxy, UnexpectedProxy());

        require(
            IPayerRegistry(proxy_).implementation() == _deploymentData.payerRegistryImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.PAYER_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        address implementation_ = PayerRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.appChainNativeToken
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.payerRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        address proxy_ = PayerRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.payerRegistryProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
