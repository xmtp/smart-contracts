// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { DistributionManagerDeployer } from "./deployers/DistributionManagerDeployer.sol";

import { IDistributionManager } from "../src/settlement-chain/interfaces/IDistributionManager.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract DistributionManagerScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error NodeRegistryProxyNotSet();
    error PayerReportManagerProxyNotSet();
    error PayerRegistryProxyNotSet();
    error AppChainNativeTokenNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.distributionManagerImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.nodeRegistryProxy != address(0), NodeRegistryProxyNotSet());
        require(_deploymentData.payerReportManagerProxy != address(0), PayerReportManagerProxyNotSet());
        require(_deploymentData.payerRegistryProxy != address(0), PayerRegistryProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = DistributionManagerDeployer
            .deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.nodeRegistryProxy,
                _deploymentData.payerReportManagerProxy,
                _deploymentData.payerRegistryProxy,
                _deploymentData.appChainNativeToken
            );

        require(implementation_ == _deploymentData.distributionManagerImplementation, UnexpectedImplementation());

        require(
            IDistributionManager(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IDistributionManager(implementation_).nodeRegistry() == _deploymentData.nodeRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IDistributionManager(implementation_).payerReportManager() == _deploymentData.payerReportManagerProxy,
            UnexpectedImplementation()
        );

        require(
            IDistributionManager(implementation_).payerRegistry() == _deploymentData.payerRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IDistributionManager(implementation_).token() == _deploymentData.appChainNativeToken,
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
            string.concat(Utils.DISTRIBUTION_MANAGER_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.distributionManagerProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.distributionManagerImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.distributionManagerProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = DistributionManagerDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.distributionManagerImplementation,
            _deploymentData.distributionManagerProxySalt
        );

        require(proxy_ == _deploymentData.distributionManagerProxy, UnexpectedProxy());

        require(
            IDistributionManager(proxy_).implementation() == _deploymentData.distributionManagerImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.DISTRIBUTION_MANAGER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.nodeRegistryProxy != address(0), NodeRegistryProxyNotSet());
        require(_deploymentData.payerReportManagerProxy != address(0), PayerReportManagerProxyNotSet());
        require(_deploymentData.payerRegistryProxy != address(0), PayerRegistryProxyNotSet());
        require(_deploymentData.appChainNativeToken != address(0), AppChainNativeTokenNotSet());

        address implementation_ = DistributionManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.appChainNativeToken
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.distributionManagerProxySalt != 0, ProxySaltNotSet());

        address proxy_ = DistributionManagerDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.distributionManagerProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
