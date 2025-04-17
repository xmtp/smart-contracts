// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { SettlementChainParameterRegistryDeployer } from "./deployers/SettlementChainParameterRegistryDeployer.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract SettlementChainParameterRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ProxySaltNotSet();

    function deployImplementation() public {
        require(_deploymentData.settlementChainParameterRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = SettlementChainParameterRegistryDeployer
            .deployImplementation(_deploymentData.factory);

        require(
            implementation_ == _deploymentData.settlementChainParameterRegistryImplementation,
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
            string.concat(
                Utils.SETTLEMENT_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON,
                "_implementation_",
                vm.toString(block.chainid)
            )
        );
    }

    function deployProxy() public {
        require(_deploymentData.parameterRegistryProxy != address(0), ProxyNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.settlementChainParameterRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.parameterRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = SettlementChainParameterRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.settlementChainParameterRegistryImplementation,
            _deploymentData.parameterRegistryProxySalt,
            _getAdmins()
        );

        require(proxy_ == _deploymentData.parameterRegistryProxy, UnexpectedProxy());

        require(
            ISettlementChainParameterRegistry(proxy_).implementation() ==
                _deploymentData.settlementChainParameterRegistryImplementation,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(_deploymentData.factory, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Utils.SETTLEMENT_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());

        address implementation_ = SettlementChainParameterRegistryDeployer.getImplementation(_deploymentData.factory);

        console.log("Implementation: %s", implementation_);
    }

    function getProxy() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.parameterRegistryProxySalt != bytes32(0), ProxySaltNotSet());

        address proxy_ = SettlementChainParameterRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.parameterRegistryProxySalt
        );

        console.log("Proxy: %s", proxy_);
    }

    function _getAdmins() internal view returns (address[] memory admins_) {
        uint256 adminCount_ = _deploymentData.settlementChainParameterRegistryAdmin1 == address(0)
            ? 0
            : _deploymentData.settlementChainParameterRegistryAdmin2 == address(0)
                ? 1
                : _deploymentData.settlementChainParameterRegistryAdmin3 == address(0)
                    ? 2
                    : 3;

        admins_ = new address[](adminCount_);

        for (uint256 index_; index_ < adminCount_; ++index_) {
            admins_[index_] = index_ == 0
                ? _deploymentData.settlementChainParameterRegistryAdmin1
                : index_ == 1
                    ? _deploymentData.settlementChainParameterRegistryAdmin2
                    : _deploymentData.settlementChainParameterRegistryAdmin3;
        }
    }
}
