// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { AppChainParameterRegistryDeployer } from "./deployers/AppChainParameterRegistryDeployer.sol";

import { IAppChainParameterRegistry } from "../src/app-chain/interfaces/IAppChainParameterRegistry.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract AppChainParameterRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.appChainParameterRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = AppChainParameterRegistryDeployer
            .deployImplementation(_deploymentData.factory);

        require(implementation_ == _deploymentData.appChainParameterRegistryImplementation, UnexpectedImplementation());

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            _deploymentData.factory,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(
                Utils.APP_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON,
                "_implementation_",
                vm.toString(block.chainid)
            )
        );
    }

    function deployProxy() public {
        require(_deploymentData.parameterRegistryProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.appChainParameterRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.parameterRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = AppChainParameterRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.appChainParameterRegistryImplementation,
            _deploymentData.parameterRegistryProxySalt,
            _getAdmins()
        );

        require(proxy_ == _deploymentData.parameterRegistryProxy, UnexpectedProxy());

        require(
            IAppChainParameterRegistry(proxy_).implementation() ==
                _deploymentData.appChainParameterRegistryImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.APP_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());

        address implementation_ = AppChainParameterRegistryDeployer.getImplementation(_deploymentData.factory);

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        address proxy_ = AppChainParameterRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.parameterRegistryProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }

    function _getAdmins() internal view returns (address[] memory admins_) {
        admins_ = new address[](1);
        admins_[0] = _deploymentData.gatewayProxy;
    }
}
