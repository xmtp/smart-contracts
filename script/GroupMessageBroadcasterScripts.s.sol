// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { GroupMessageBroadcasterDeployer } from "./deployers/GroupMessageBroadcasterDeployer.sol";

import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract GroupMessageBroadcasterScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.groupMessageBroadcasterImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = GroupMessageBroadcasterDeployer
            .deployImplementation(_deploymentData.factory, _deploymentData.parameterRegistryProxy);

        require(implementation_ == _deploymentData.groupMessageBroadcasterImplementation, UnexpectedImplementation());

        require(
            IGroupMessageBroadcaster(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
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
            string.concat(Utils.GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.groupMessageBroadcasterProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.groupMessageBroadcasterImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.groupMessageBroadcasterProxySalt != bytes32(0), ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = GroupMessageBroadcasterDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.groupMessageBroadcasterImplementation,
            _deploymentData.groupMessageBroadcasterProxySalt
        );

        require(proxy_ == _deploymentData.groupMessageBroadcasterProxy, UnexpectedProxy());

        require(
            IGroupMessageBroadcaster(proxy_).implementation() == _deploymentData.groupMessageBroadcasterImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        address implementation_ = GroupMessageBroadcasterDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.groupMessageBroadcasterProxySalt != bytes32(0), ProxySaltNotSet());

        address proxy_ = GroupMessageBroadcasterDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.groupMessageBroadcasterProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
