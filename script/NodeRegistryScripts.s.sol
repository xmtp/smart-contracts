// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { NodeRegistryDeployer } from "./deployers/NodeRegistryDeployer.sol";

import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract NodeRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.nodeRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = NodeRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        require(implementation_ == _deploymentData.nodeRegistryImplementation, UnexpectedImplementation());

        require(
            INodeRegistry(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
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
            string.concat(Utils.NODE_REGISTRY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.nodeRegistryProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.nodeRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.nodeRegistryProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = NodeRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.nodeRegistryImplementation,
            _deploymentData.nodeRegistryProxySalt
        );

        require(proxy_ == _deploymentData.nodeRegistryProxy, UnexpectedProxy());

        require(
            INodeRegistry(proxy_).implementation() == _deploymentData.nodeRegistryImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(json_, string.concat(Utils.NODE_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid)));
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        address implementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.nodeRegistryProxySalt != 0, ProxySaltNotSet());

        address proxy_ = NodeRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.nodeRegistryProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
