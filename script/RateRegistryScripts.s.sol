// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { RateRegistryDeployer } from "./deployers/RateRegistryDeployer.sol";

import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract RateRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.rateRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = RateRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        require(implementation_ == _deploymentData.rateRegistryImplementation, UnexpectedImplementation());

        require(
            IRateRegistry(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
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
            string.concat(Utils.RATE_REGISTRY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.rateRegistryProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.rateRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.rateRegistryProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = RateRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.rateRegistryImplementation,
            _deploymentData.rateRegistryProxySalt
        );

        require(proxy_ == _deploymentData.rateRegistryProxy, UnexpectedProxy());

        require(
            IRateRegistry(proxy_).implementation() == _deploymentData.rateRegistryImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(json_, string.concat(Utils.RATE_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid)));
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        address implementation_ = RateRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.rateRegistryProxySalt != 0, ProxySaltNotSet());

        address proxy_ = RateRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.rateRegistryProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
