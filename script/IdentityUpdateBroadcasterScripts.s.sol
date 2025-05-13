// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { IdentityUpdateBroadcasterDeployer } from "./deployers/IdentityUpdateBroadcasterDeployer.sol";

import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract IdentityUpdateBroadcasterScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.identityUpdateBroadcasterImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = IdentityUpdateBroadcasterDeployer
            .deployImplementation(_deploymentData.factory, _deploymentData.parameterRegistryProxy);

        require(implementation_ == _deploymentData.identityUpdateBroadcasterImplementation, UnexpectedImplementation());

        require(
            IIdentityUpdateBroadcaster(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
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
            string.concat(Utils.IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.identityUpdateBroadcasterProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.identityUpdateBroadcasterImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.identityUpdateBroadcasterProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.identityUpdateBroadcasterImplementation,
            _deploymentData.identityUpdateBroadcasterProxySalt
        );

        require(proxy_ == _deploymentData.identityUpdateBroadcasterProxy, UnexpectedProxy());

        require(
            IIdentityUpdateBroadcaster(proxy_).implementation() ==
                _deploymentData.identityUpdateBroadcasterImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());

        address implementation_ = IdentityUpdateBroadcasterDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.identityUpdateBroadcasterProxySalt != 0, ProxySaltNotSet());

        address proxy_ = IdentityUpdateBroadcasterDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.identityUpdateBroadcasterProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
