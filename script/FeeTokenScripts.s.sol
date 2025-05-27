// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { FeeTokenDeployer } from "./deployers/FeeTokenDeployer.sol";

import { IFeeToken } from "../src/settlement-chain/interfaces/IFeeToken.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract FeeTokenScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error UnderlyingFeeTokenNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.feeTokenImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.underlyingFeeToken != address(0), UnderlyingFeeTokenNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = FeeTokenDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.underlyingFeeToken
        );

        require(implementation_ == _deploymentData.feeTokenImplementation, UnexpectedImplementation());

        require(
            IFeeToken(implementation_).parameterRegistry() == _deploymentData.parameterRegistryProxy,
            UnexpectedImplementation()
        );

        require(
            IFeeToken(implementation_).underlying() == _deploymentData.underlyingFeeToken,
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
            string.concat(Utils.FEE_TOKEN_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(_deploymentData.feeTokenProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.feeTokenImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.feeTokenProxySalt != 0, ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = FeeTokenDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.feeTokenImplementation,
            _deploymentData.feeTokenProxySalt
        );

        require(proxy_ == _deploymentData.feeTokenProxy, UnexpectedProxy());

        require(IFeeToken(proxy_).implementation() == _deploymentData.feeTokenImplementation, UnexpectedProxy());

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(json_, string.concat(Utils.FEE_TOKEN_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid)));
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxy != address(0), ParameterRegistryProxyNotSet());
        require(_deploymentData.underlyingFeeToken != address(0), UnderlyingFeeTokenNotSet());

        address implementation_ = FeeTokenDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.underlyingFeeToken
        );

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.feeTokenProxySalt != 0, ProxySaltNotSet());

        address proxy_ = FeeTokenDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.feeTokenProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }
}
