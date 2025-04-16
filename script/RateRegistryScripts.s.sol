// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { RateRegistryDeployer } from "./deployers/RateRegistryDeployer.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract RateRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error AdminNotSet();
    error RateRegistrySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.rateRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = RateRegistryDeployer.deployImplementation(
            _deploymentData.factory
        );

        require(implementation_ == _deploymentData.rateRegistryImplementation, UnexpectedImplementation());

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
        require(_deploymentData.rateRegistryAdmin != address(0), AdminNotSet());
        require(_deploymentData.rateRegistrySalt != bytes32(0), RateRegistrySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = RateRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.rateRegistryImplementation,
            _deploymentData.rateRegistrySalt,
            _deploymentData.rateRegistryAdmin
        );

        require(proxy_ == _deploymentData.rateRegistryProxy, UnexpectedProxy());

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(json_, string.concat(Utils.RATE_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid)));
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());

        address implementation_ = RateRegistryDeployer.getImplementation(_deploymentData.factory);

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.rateRegistrySalt != bytes32(0), RateRegistrySaltNotSet());

        address proxy_ = RateRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.rateRegistrySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
