// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/Script.sol";

import { NodeRegistryDeployer } from "./deployers/NodeRegistryDeployer.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract NodeRegistryScripts is ScriptBase {
    error ImplementationNotSet();
    error UnexpectedImplementation();
    error FactoryNotSet();
    error AdminNotSet();

    function deployImplementation() public {
        require(_deploymentData.nodeRegistryImplementation != address(0), ImplementationNotSet());
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.nodeRegistryAdmin != address(0), AdminNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = NodeRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.nodeRegistryAdmin
        );

        require(implementation_ == _deploymentData.nodeRegistryImplementation, UnexpectedImplementation());

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

    function getImplementation() public view {
        require(_deploymentData.factory != address(0), FactoryNotSet());
        require(_deploymentData.nodeRegistryAdmin != address(0), AdminNotSet());

        address implementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.nodeRegistryAdmin
        );

        console.log("Implementation: %s", implementation_);
    }
}
