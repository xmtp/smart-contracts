// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { PayerReportManagerDeployer } from "./deployers/PayerReportManagerDeployer.sol";

import { IPayerReportManager } from "../src/settlement-chain/interfaces/IPayerReportManager.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract PayerReportManagerScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error NodeRegistryProxyNotSet();
    error PayerRegistryProxyNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.payerReportManagerImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.nodeRegistryProxy != address(0), NodeRegistryProxyNotSet());
        require(_deploymentData.payerRegistryProxy != address(0), PayerRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = PayerReportManagerDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        require(implementation_ == _deploymentData.payerReportManagerImplementation, UnexpectedImplementation());

        require(
            IPayerReportManager(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IPayerReportManager(implementation_).nodeRegistry() == _deploymentData.nodeRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IPayerReportManager(implementation_).payerRegistry() == _deploymentData.payerRegistryProxy,
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
            string.concat(Utils.PAYER_REPORT_MANAGER_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.payerReportManagerProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.payerReportManagerImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.payerReportManagerProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = PayerReportManagerDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.payerReportManagerImplementation,
            _deploymentData.payerReportManagerProxySalt
        );

        require(proxy_ == _deploymentData.payerReportManagerProxy, UnexpectedProxy());

        require(
            IPayerReportManager(proxy_).implementation() == _deploymentData.payerReportManagerImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.PAYER_REPORT_MANAGER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.nodeRegistryProxy != address(0), NodeRegistryProxyNotSet());
        require(_deploymentData.payerRegistryProxy != address(0), PayerRegistryProxyNotSet());

        address implementation_ = PayerReportManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.payerReportManagerProxySalt != 0, ProxySaltNotSet());

        address proxy_ = PayerReportManagerDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.payerReportManagerProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
